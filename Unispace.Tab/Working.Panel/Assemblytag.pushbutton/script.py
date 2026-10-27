# -*- coding: utf-8 -*-
"""Manually refresh 'Sheet Ref' on all assembly instances."""
__title__ = "Assembly\nSheet Refs"

from pyrevit import revit, DB, script, forms
import sheet_ref_lib

doc = revit.doc
out = script.get_output()

instances = list(DB.FilteredElementCollector(doc).OfClass(DB.AssemblyInstance))
if not instances:
    forms.alert("No assembly instances found in this model.", exitscript=True)
if not sheet_ref_lib.parameter_is_available(instances):
    forms.alert("The shared parameter 'Sheet Ref' was not found on assembly "
                "instances (or is not a text parameter).", exitscript=True)

with revit.Transaction("Populate assembly sheet refs"):
    updated, unchanged, failed = sheet_ref_lib.apply_sheet_refs(doc, instances)

out.print_md("### Assembly sheet refs")
out.print_md("**Updated:** {}  |  **Unchanged:** {}  |  **Failed:** {}".format(
    len(updated), len(unchanged), len(failed)))
for inst, value in updated:
    out.print_md("- {} {} -> `{}`".format(
        out.linkify(inst.Id), inst.Name, value or "(cleared)"))
for inst, reason in failed:
    out.print_md("- {} {}: {}".format(out.linkify(inst.Id), inst.Name, reason))
