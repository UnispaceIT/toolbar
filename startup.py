# -*- coding: utf-8 -*-
"""Registers an updater that keeps 'Sheet Ref' in sync automatically."""
from System import Guid
from pyrevit import HOST_APP, DB, script
import sheet_ref_lib

logger = script.get_logger()
UPDATER_GUID = Guid("7c1d5e52-3b0a-4c58-9f41-2a6d8e0b1f93")


class SheetRefUpdater(DB.IUpdater):
    def __init__(self, addin_id):
        self._id = DB.UpdaterId(addin_id, UPDATER_GUID)

    def Execute(self, data):
        try:
            doc = data.GetDocument()
            if doc.IsFamilyDocument:
                return
            sheet_ref_lib.apply_sheet_refs(doc)
        except Exception as ex:
            logger.warning("Sheet Ref updater failed: {}".format(ex))

    def GetUpdaterId(self):
        return self._id

    def GetUpdaterName(self):
        return "Assembly Sheet Ref Updater"

    def GetAdditionalInformation(self):
        return "Keeps the Sheet Ref parameter on assemblies in sync with sheets."

    def GetChangePriority(self):
        return DB.ChangePriority.Annotations


def register():
    updater = SheetRefUpdater(HOST_APP.app.ActiveAddInId)
    uid = updater.GetUpdaterId()

    # pyRevit reload: drop the stale instance first
    if DB.UpdaterRegistry.IsUpdaterRegistered(uid):
        DB.UpdaterRegistry.UnregisterUpdater(uid)

    # isOptional=True -> models open without warnings on machines without it
    DB.UpdaterRegistry.RegisterUpdater(updater, True)

    add = DB.Element.GetChangeTypeElementAddition()
    delete = DB.Element.GetChangeTypeElementDeletion()
    sheet_number = DB.Element.GetChangeTypeParameter(
        DB.ElementId(DB.BuiltInParameter.SHEET_NUMBER))

    sheet_filter = DB.ElementClassFilter(DB.ViewSheet)
    DB.UpdaterRegistry.AddTrigger(uid, sheet_filter, sheet_number)  # renumber
    DB.UpdaterRegistry.AddTrigger(uid, sheet_filter, delete)        # sheet deleted

    for cls in (DB.Viewport, DB.ScheduleSheetInstance, DB.AssemblyInstance):
        f = DB.ElementClassFilter(cls)
        DB.UpdaterRegistry.AddTrigger(uid, f, add)      # placed / created
        if cls is not DB.AssemblyInstance:
            DB.UpdaterRegistry.AddTrigger(uid, f, delete)  # removed from sheet


try:
    register()
except Exception as ex:
    logger.error("Could not register Sheet Ref updater: {}".format(ex))
