#!/usr/bin/env python3
"""Unit tests for the patch engine in nix/engine.

Tests covering a bug that actually shipped say so, so a regression reads as one.
"""

import os
import subprocess
import sys
import tempfile
import textwrap
import types
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO_ROOT, "nix"))

from engine import configmerge, cli, csource, diffs, ordering, reconcile, tagmacros, threeway

# Reached by name regardless of module, so the split stays an implementation detail.
engine = types.SimpleNamespace(
    **{
        name: value
        for module in (ordering, csource, diffs, configmerge, tagmacros, threeway, reconcile)
        for name, value in vars(module).items()
        if not name.startswith("__")
    }
)


def patch_path(name):
    """A patch path shaped like the ones the build passes in."""
    return f"/nix/store/aaaa-dwl-patches/patches/{name}/{name}.patch"


class PatchOrdering(unittest.TestCase):
    def rank(self, name):
        return engine.get_patch_rank(patch_path(name))

    def test_bar_is_applied_before_everything_that_builds_on_it(self):
        for dependent in ("barpadding", "barcolors", "vanitygaps", "pertag", "gaplessgrid"):
            self.assertLess(self.rank("bar"), self.rank(dependent), dependent)

    def test_hyphenated_bar_addons_rank_with_the_other_addons(self):
        """Regression: the rank table matched by equality, so these fell through to
        the catch-all rank and were applied after pertag instead of after bar."""
        for addon in ("bar-awesomebar", "bar-notitle"):
            self.assertEqual(self.rank(addon), self.rank("barpadding"), addon)

    def test_phases_are_ordered_addons_then_gaps_then_layouts_then_tagging(self):
        self.assertLess(self.rank("barpadding"), self.rank("vanitygaps"))
        self.assertLess(self.rank("vanitygaps"), self.rank("gaplessgrid"))
        self.assertLess(self.rank("gaplessgrid"), self.rank("movestack"))
        self.assertLess(self.rank("movestack"), self.rank("pertag"))

    def test_sorting_reorders_a_user_list_but_keeps_ties_stable(self):
        given = [patch_path(n) for n in ("pertag", "barcolors", "vanitygaps", "bar", "barpadding")]
        got = [p.split("/")[-2] for p in engine.sort_patches(given)]
        self.assertEqual(got, ["bar", "barcolors", "barpadding", "vanitygaps", "pertag"])


class CommentAndStringStripping(unittest.TestCase):
    def test_offsets_are_preserved_so_insertions_stay_aligned(self):
        code = 'int a; /* comment */ int b; // trailing\nchar *s = "text";\n'
        clean = engine.strip_comments_and_strings(code)
        self.assertEqual(len(clean), len(code))
        self.assertEqual(clean.count("\n"), code.count("\n"))

    def test_comment_and_string_bodies_are_blanked(self):
        clean = engine.strip_comments_and_strings('/* tags */ x; char *s = "tags";')
        self.assertNotIn("tags", clean)
        self.assertIn("x;", clean)

    def test_a_symbol_named_only_in_a_comment_is_not_declared(self):
        """Regression: `rg -q "\\btags\\b"` hit "tags mask" in a comment, so tags[]
        was thought declared, dropped, and the build broke with vanitygaps before bar."""
        code = "/* tagging - tags mask, TAGCOUNT must be no greater than 31 */\n"
        self.assertFalse(engine.is_symbol_declared("tags", code))
        self.assertFalse(engine.is_symbol_declared("TAGCOUNT", code))

    def test_a_real_declaration_is_found(self):
        self.assertTrue(engine.is_symbol_declared("tags", 'static char *tags[] = { "1", "2" };'))
        self.assertTrue(engine.is_symbol_declared("TAGCOUNT", "#define TAGCOUNT 9\n"))

    def test_bracketed_names_do_not_blow_up_the_matcher(self):
        """Regression: names went into a regex unescaped, so colors[][3] became a
        character class and corrupted config.h."""
        code = "static uint32_t colors[][3] = { { 0, 0, 0 } };\n"
        self.assertTrue(engine.is_symbol_declared("colors", code))
        self.assertFalse(engine.is_symbol_declared("colors[][3]", code))


class ThreeWayConflictResolution(unittest.TestCase):
    CX_BASE = "\t\t\tcx = (cursor->x - selmon->m.x) * selmon->wlr_output->scale;"
    CX_PADDING = "\t\t\tcx = (cursor->x - selmon->m.x - sidepad) * selmon->wlr_output->scale;"
    CX_BORDER = "\t\t\tcx = (cursor->x - selmon->m.x - borderpx) * selmon->wlr_output->scale;"

    def test_a_single_inserted_run_is_detected(self):
        self.assertEqual(
            engine._single_point_insertion("ab", "aXb"), (1, "X")
        )
        self.assertEqual(
            engine._single_point_insertion(self.CX_BASE, self.CX_PADDING)[1], " - sidepad"
        )

    def test_unrelated_rewrites_are_not_insertions(self):
        self.assertIsNone(engine._single_point_insertion("int a;", "int b;"))
        self.assertIsNone(engine._single_point_insertion("long", "int"))

    def test_two_patches_offsetting_the_same_expression_keep_both_terms(self):
        """barpadding and barborder each subtract their own offset from the same
        cursor expression, so both terms have to survive."""
        merged = engine._merge_additive_line(self.CX_BASE, self.CX_PADDING, self.CX_BORDER)
        self.assertIsNotNone(merged)
        self.assertIn("- sidepad", merged)
        self.assertIn("- borderpx", merged)

    def test_conflicting_rewrites_of_one_line_are_refused(self):
        self.assertIsNone(
            engine._merge_additive_line("x = a;", "x = compute(a);", "x = other(a);")
        )

    def test_each_side_editing_a_different_line_is_not_a_real_conflict(self):
        base = ["if ((w = m->b.width - tw - x) > m->b.height) {", "\tif (c) {"]
        ours = ["if ((w = m->b.width - tw - x) > m->b.height) {", "\tif (c && window_title) {"]
        theirs = ["if ((w = mw - tw - x + borderpx) > mh) {", "\tif (c) {"]
        self.assertEqual(engine._resolve_line_wise(ours, base, theirs), [theirs[0], ours[1]])

    def test_identical_edits_on_both_sides_collapse(self):
        self.assertEqual(engine._resolve_line_wise(["a"], ["b"], ["a"]), ["a"])

    def test_regions_of_differing_length_are_left_to_a_human(self):
        self.assertIsNone(engine._resolve_line_wise(["a", "b"], ["a"], ["c"]))

    def test_diff3_markers_are_resolved_in_place(self):
        merged = engine.resolve_conflict_markers(
            "before\n"
            "<<<<<<< ours\n" + self.CX_PADDING + "\n"
            "||||||| base\n" + self.CX_BASE + "\n"
            "=======\n" + self.CX_BORDER + "\n"
            ">>>>>>> theirs\n"
            "after\n"
        )
        self.assertIsNotNone(merged)
        self.assertNotIn("<<<<<<<", merged)
        self.assertIn("- sidepad - borderpx", merged)
        self.assertTrue(merged.startswith("before\n"))
        self.assertIn("after", merged)

    def test_an_unresolvable_block_reports_failure_rather_than_guessing(self):
        self.assertIsNone(
            engine.resolve_conflict_markers(
                "<<<<<<< ours\nint a = one();\n"
                "||||||| base\nint a;\n"
                "=======\nint a = two();\n"
                ">>>>>>> theirs\n"
            )
        )

    def test_a_truncated_block_is_not_silently_accepted(self):
        self.assertIsNone(engine.resolve_conflict_markers("<<<<<<< ours\nint a;\n"))


class ConflictReporting(unittest.TestCase):
    """Some patch pairs genuinely cannot be merged. The engine must name which two
    disagree instead of dumping a raw hunk."""

    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="dwl-report-")

    def write_patch(self, name, added):
        directory = os.path.join(self.dir, name)
        os.makedirs(directory, exist_ok=True)
        path = os.path.join(directory, f"{name}.patch")
        body = "".join(f"+{line}\n" for line in added)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write("--- a/dwl.c\n+++ b/dwl.c\n@@ -1,1 +1,2 @@\n" + body)
        return path

    def test_the_patch_name_is_taken_from_its_directory(self):
        self.assertEqual(
            engine.patch_display_name("/store/x/patches/barborder/barborder.patch"),
            "barborder",
        )

    def test_unresolved_blocks_are_handed_back_to_the_caller(self):
        unresolved = []
        merged = engine.resolve_conflict_markers(
            "<<<<<<< ours\nint a = one();\n"
            "||||||| base\nint a;\n"
            "=======\nint a = two();\n"
            ">>>>>>> theirs\n",
            unresolved,
        )
        self.assertIsNone(merged)
        self.assertEqual(len(unresolved), 1)
        self.assertEqual(unresolved[0][0], ["int a = one();"])
        self.assertEqual(unresolved[0][2], ["int a = two();"])

    def test_the_patch_that_introduced_the_conflicting_line_is_named(self):
        guilty = self.write_patch("barcolors", ["tw = drawstatus(m); /* long enough */"])
        innocent = self.write_patch("vanitygaps", ["int unrelated_gap_value = 12;"])
        blocks = [[["tw = drawstatus(m); /* long enough */"], ["tw = 0;"], ["tw = other();"]]]
        self.assertEqual(
            engine.blame_conflicting_patches(blocks, [guilty, innocent]), ["barcolors"]
        )

    def test_the_report_names_both_patches_and_says_what_to_do(self):
        guilty = self.write_patch("barcolors", ["tw = drawstatus(m); /* long enough */"])
        blocks = [[["tw = drawstatus(m); /* long enough */"], ["tw = 0;"], ["tw = other();"]]]
        report = engine.format_conflict_report(
            "dwl.c", "/store/x/patches/barborder/barborder.patch", blocks, [guilty]
        )
        self.assertIn("barborder", report)
        self.assertIn("barcolors", report)
        self.assertIn("dwl.c", report)
        self.assertIn("drop one of the conflicting patches", report)


class StructReconciliation(unittest.TestCase):
    CLIENT = textwrap.dedent(
        """\
        typedef struct {
        \tstruct wl_list link;
        \tunsigned int tags;
        } Client;
        """
    )

    def test_a_struct_body_is_located(self):
        loc = engine.locate_struct_definition(self.CLIENT, "Client")
        self.assertIsNotNone(loc)
        self.assertIn("unsigned int tags;", loc.raw_body)

    def test_existing_members_are_read_back(self):
        loc = engine.locate_struct_definition(self.CLIENT, "Client")
        self.assertEqual(engine.parse_existing_members(loc.raw_body), {"link", "tags"})

    def test_a_new_member_is_inserted_inside_the_braces(self):
        updated = engine.insert_field_into_struct(self.CLIENT, "Client", "\tint isterm;")
        self.assertIn("isterm", updated)
        self.assertEqual(updated.count("} Client;"), 1)
        self.assertLess(updated.index("isterm"), updated.index("} Client;"))

    def test_inserting_a_member_that_already_exists_is_a_no_op(self):
        once = engine.insert_field_into_struct(self.CLIENT, "Client", "\tunsigned int tags;")
        self.assertEqual(once.count("tags;"), 1)


class ConfigArrayMerging(unittest.TestCase):
    CONFIG = textwrap.dedent(
        """\
        static const Layout layouts[] = {
        \t{ "[]=", tile },
        \t{ "><>", NULL },
        };
        """
    )

    def test_a_rejected_layout_is_appended_rather_than_dropped(self):
        """Regression: rejected layout entries went to a .dropped file, so deck and
        friends were compiled but never referenced, warning about unused functions."""
        updated, index = engine.merge_layouts_array(self.CONFIG, ['+\t{ "[E]", deck },'])
        self.assertRegex(updated, r'\{\s*"\[E\]"\s*,\s*deck\s*\}')
        self.assertIn("deck", index)
        self.assertLess(updated.index("deck"), updated.index("};"))

    def test_an_already_present_layout_is_not_duplicated(self):
        updated, _ = engine.merge_layouts_array(self.CONFIG, ['+\t{ "[]=", tile },'])
        self.assertEqual(updated.count('{ "[]=", tile }'), 1)


class PatchParsing(unittest.TestCase):
    PATCH = textwrap.dedent(
        """\
        From abc Mon Sep 17 00:00:00 2001
        Subject: [PATCH] example

        diff --git a/dwl.c b/dwl.c
        --- a/dwl.c
        +++ b/dwl.c
        @@ -10,3 +10,4 @@ context
         keep one
        -drop this
        +add this
        +add that
         keep two
        diff --git a/config.def.h b/config.def.h
        --- a/config.def.h
        +++ b/config.def.h
        @@ -1,2 +1,3 @@
         static int x;
        +static int y;
        --
        2.46.0
        """
    )

    def test_both_files_are_parsed(self):
        diffs = engine.parse_patch_content(self.PATCH)
        self.assertEqual([d.target_file() for d in diffs], ["dwl.c", "config.def.h"])

    def test_added_and_removed_lines_are_separated(self):
        dwl = engine.parse_patch_content(self.PATCH)[0]
        self.assertEqual(dwl.hunks[0].added_lines, ["add this", "add that"])
        self.assertEqual(dwl.hunks[0].removed_lines, ["drop this"])

    def test_the_git_trailer_is_not_read_as_patch_content(self):
        config = engine.parse_patch_content(self.PATCH)[1]
        self.assertEqual(config.hunks[0].added_lines, ["static int y;"])


class TagMacroBridging(unittest.TestCase):
    """bar replaces TAGCOUNT with LENGTH(tags), so combining it with a patch that
    still says TAGCOUNT needs a bridge, while a lone patch must stay untouched."""

    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="dwl-tagmacro-")

    def write(self, name, text):
        with open(os.path.join(self.dir, name), "w", encoding="utf-8") as handle:
            handle.write(text)

    def read(self, name):
        with open(os.path.join(self.dir, name), encoding="utf-8") as handle:
            return handle.read()

    def test_tagcount_is_bridged_to_the_tags_array_when_it_is_undefined(self):
        self.write("dwl.c", '#include "config.h"\nint n = TAGCOUNT;\n')
        self.write("config.def.h", 'static char *tags[] = { "1", "2" };\n')
        engine.reconcile_tag_macros(target_dir=self.dir)
        self.assertIn("#define TAGCOUNT LENGTH(tags)", self.read("dwl.c"))

    def test_an_already_defined_tagcount_is_left_alone(self):
        """Regression: the bridge was unconditional, adding three lines to every
        single-patch tree and breaking upstream comparison for nine patches."""
        self.write("dwl.c", '#include "config.h"\nint n = TAGCOUNT;\n')
        self.write("config.def.h", "#define TAGCOUNT 9\n")
        before = self.read("dwl.c")
        engine.reconcile_tag_macros(target_dir=self.dir)
        self.assertEqual(self.read("dwl.c"), before)

    def test_a_tree_that_never_mentions_tagcount_is_left_alone(self):
        self.write("dwl.c", '#include "config.h"\nint n = 1;\n')
        self.write("config.def.h", 'static char *tags[] = { "1" };\n')
        before = self.read("dwl.c")
        engine.reconcile_tag_macros(target_dir=self.dir)
        self.assertEqual(self.read("dwl.c"), before)


class EngineCommandLine(unittest.TestCase):
    def run_engine(self, *args):
        env = dict(os.environ, PYTHONPATH=os.path.join(REPO_ROOT, "nix"))
        return subprocess.run(
            [sys.executable, "-m", "engine", *args],
            capture_output=True, text=True, env=env,
        )

    def test_no_patches_is_a_successful_no_op(self):
        self.assertEqual(self.run_engine("--target", ".").returncode, 0)

    def test_a_missing_patch_file_fails_with_a_message_naming_it(self):
        result = self.run_engine("--target", ".", "/nonexistent/nope.patch")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("nope.patch", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
