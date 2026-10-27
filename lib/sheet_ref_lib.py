# -*- coding: utf-8 -*-
"""Shared logic for populating 'Sheet Ref' on assembly instances.
Used by the manual button and by the automatic updater."""
from System import Guid
from pyrevit import DB

PARAM_GUID = Guid("fa00b293-a98b-449e-8ceb-a34e22b79b39")  # Sheet Ref
PARAM_NAME = "Sheet Ref"
SEPARATOR = ", "
NOT_PLACED = ""


def get_sheet_ref_param(inst):
    param = inst.get_Parameter(PARAM_GUID)
    if param is None:
        param = inst.LookupParameter(PARAM_NAME)
    return param


def collect_sheet_numbers_by_assembly(doc):
    found = {}

    def register(view, sheet):
        if view is None or sheet is None:
            return
        asm_id = view.AssociatedAssemblyInstanceId
        if asm_id is None or asm_id == DB.ElementId.InvalidElementId:
            return
        found.setdefault(asm_id.ToString(), set()).add(sheet.SheetNumber)

    for sheet in DB.FilteredElementCollector(doc).OfClass(DB.ViewSheet):
        for vp_id in sheet.GetAllViewports():
            vp = doc.GetElement(vp_id)
            register(doc.GetElement(vp.ViewId), sheet)

    for ssi in DB.FilteredElementCollector(doc).OfClass(DB.ScheduleSheetInstance):
        sheet = doc.GetElement(ssi.OwnerViewId)
        if not isinstance(sheet, DB.ViewSheet):
            continue
        register(doc.GetElement(ssi.ScheduleId), sheet)

    return found


def parameter_is_available(instances):
    """True if Sheet Ref exists as a text parameter on assemblies."""
    if not instances:
        return False
    probe = get_sheet_ref_param(instances[0])
    return probe is not None and probe.StorageType == DB.StorageType.String


def _owned_by_other_user(doc, inst):
    if not doc.IsWorkshared:
        return False
    status = DB.WorksharingUtils.GetCheckoutStatus(doc, inst.Id)
    return status == DB.CheckoutStatus.OwnedByOtherUser


def apply_sheet_refs(doc, instances=None):
    """Recompute and write Sheet Ref. Does NOT open a transaction, so the
    caller (button transaction or updater) controls that.
    Returns (updated, unchanged, failed)."""
    if instances is None:
        instances = list(DB.FilteredElementCollector(doc)
                         .OfClass(DB.AssemblyInstance))
    updated, unchanged, failed = [], [], []
    if not parameter_is_available(instances):
        return updated, unchanged, failed

    by_assembly = collect_sheet_numbers_by_assembly(doc)

    by_type = {}
    for inst in instances:
        sheets = by_assembly.get(inst.Id.ToString())
        if sheets:
            by_type.setdefault(inst.GetTypeId().ToString(), set()).update(sheets)

    for inst in instances:
        sheets = by_type.get(inst.GetTypeId().ToString())
        value = SEPARATOR.join(sorted(sheets)) if sheets else NOT_PLACED

        param = get_sheet_ref_param(inst)
        if (param is None or param.IsReadOnly
                or param.StorageType != DB.StorageType.String):
            failed.append((inst, "parameter missing or read-only"))
            continue

        if (param.AsString() or "") == value:
            unchanged.append(inst)
            continue

        if _owned_by_other_user(doc, inst):
            failed.append((inst, "element owned by another user"))
            continue

        try:
            param.Set(value)
            updated.append((inst, value))
        except Exception as ex:
            failed.append((inst, str(ex)))

    return updated, unchanged, failed
