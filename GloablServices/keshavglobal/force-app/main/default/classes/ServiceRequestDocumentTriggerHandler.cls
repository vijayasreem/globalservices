public class ServiceRequestDocumentTriggerHandler extends TriggerHandler {
    /* Trigger Variables */
    List<Service_Request_Document__c> triggerNew;
    Map<Id, Service_Request_Document__c> triggerOldMap;

    /* Constructor */
    public ServiceRequestDocumentTriggerHandler() {
        triggerNew = (List<Service_Request_Document__c>) trigger.new;
        triggerOldMap = (Map<Id, Service_Request_Document__c>) trigger.oldMap;
    }

    /* Handle Trigger Events */

    public override void beforeUpdate() {
        updateServiceRequest(triggerOldMap, triggerNew);
    }

    public override void afterUpdate() {
        CreateReviewTaskOnServiceRequestDetails(triggerOldMap, triggerNew);
        CreateReviewTaskOnServiceRequest(triggerOldMap, triggerNew);
        updateServiceRequestDocumentStatus(triggerNew, triggerOldMap);
        SendDoctoCase360SRDcomplete(triggerOldMap, triggerNew);
    }

    public static void updateServiceRequestDocumentStatus(List<Service_Request_Document__c> triggerNew, Map<Id, Service_Request_Document__c> triggerOldMap) {
        List<Case_Action_Result__c> caseActionResultList = new List<Case_Action_Result__c>();
        List<Service_Request_Document__c> docList = new List<Service_Request_Document__c>();
        if (triggerOldMap != null) {
            Set<Id> SRIdSet = new Set<Id>();
            for (Service_Request_Document__c doc : triggerNew) {
                if (doc.Status__c != triggerOldMap.get(doc.Id).Status__c && doc.Status__c != null && doc.Status__c != 'Archived') {
                    SRIdSet.add(doc.Service_Request__c);
                }
            }
            Map<String, List<Boolean>> srdCompleteMap = new Map<String, List<Boolean>>();
            Map<String, List<Service_Request_Line_Item__c>> srAndSRDListMap = new Map<String, List<Service_Request_Line_Item__c>>();
            if (SRIdSet != null && SRIdSet.size() > 0) {
                srAndSRDListMap = SRLineItemQueryselector.getrelatedServiceReqDetails(SRIdSet);
            }
            for (Service_Request_Document__c doc : triggerNew) {
                Map<Id, Service_Request_Line_Item__c> srdmap = new Map<Id, Service_Request_Line_Item__c>();
                if (srAndSRDListMap.containsKey(doc.Service_Request__c)) {
                    srdmap = new Map<Id, Service_Request_Line_Item__c>(srAndSRDListMap.get(doc.Service_Request__c));
                }
                if (srdmap.containsKey(doc.Service_Request_Line_Item__c)) {
                    if (doc.Status__c != triggerOldMap.get(doc.Id).Status__c && doc.Status__c == Constants.SRD_STATUS_MATCHED && srdmap.get(doc.Service_Request_Line_Item__c).Status__c != Constants.SRD_STATUS_COMPLETE) {
                        caseActionResultList.add(manageCaseActionResults.prepareCaseActionResult('Receive', doc.Intake_Request__c, 'Document Matched', 'Needs Review', '', '', userInfo.getUserId(), ''));
                    }
                    if (doc.Status__c != triggerOldMap.get(doc.Id).Status__c && doc.Status__c == Constants.SRD_STATUS_MATCHED && srdmap.get(doc.Service_Request_Line_Item__c).Status__c == Constants.SRD_STATUS_COMPLETE) {
                        caseActionResultList.add(manageCaseActionResults.prepareCaseActionResult('Receive', doc.Intake_Request__c, 'Document Matched', 'Send to Customer', '', '', userInfo.getUserId(), ''));
                    }
                }

            }
            if (SRIdSet != null && SRIdSet.size() > 0) {
                docList = [SELECT Id, Status__c, Service_Request__c, Service_Request_Line_Item__c,
                           Service_Request_Line_Item__r.Status__c,
                           case360DocumentId__c, Service_Request__r.Status__c,
                           Service_Request_Line_Item__r.Reason_Code__c
                           FROM Service_Request_Document__c
                           WHERE Service_Request__c IN :SRIdSet
                           AND Service_Request_Line_Item__r.Reason_Code__c != :Constants.SRD_RESULT_CANCEL];
            }
            Map<String, List<Service_Request_Document__c>> srdocListMap = new Map<String, List<Service_Request_Document__c>>();
            if (docList != null && docList.size() > 0) {
                for (Service_Request_Document__c doc : docList) {
                    if (srdocListMap.containsKey(doc.Service_Request__c)) {
                        srdocListMap.get(doc.Service_Request__c).add(doc);
                    } else {
                        srdocListMap.put(doc.Service_Request__c, new List<Service_Request_Document__c>{doc});
                    }
                }
            }
            List<Service_Request__c> srList = new List<Service_Request__c>();
            if (srdocListMap != null && srdocListMap.size() > 0) {
                for (String srId : srdocListMap.keySet()) {
                    Boolean isSRDocumentDelivery = false;
                    Boolean isSRDDocumentDelivery = false;
                    Boolean docDeliveryStatus = false;
                    for (Service_Request_Document__c doc : srdocListMap.get(srId)) {
                        if (doc.Status__c == 'Delivered' || doc.Status__c == 'Delivery Failed' || doc.Status__c == 'Archived') {
                            docDeliveryStatus = true;
                        } else {
                            docDeliveryStatus = false;
                        }
                        if (doc.Status__c == 'Delivered' || doc.Status__c == 'Archived') {
                            if (doc.Service_Request_Line_Item__r.Status__c == Constants.SRD_STATUS_COMPLETE) {
                                isSRDDocumentDelivery = true;
                            } else {
                                isSRDDocumentDelivery = false;
                            }
                            isSRDocumentDelivery = true;
                        } else {
                            isSRDDocumentDelivery = false;
                            isSRDocumentDelivery = false;
                            break;
                        }

                    }
                    if (srAndSRDListMap != null && srAndSRDListMap.size() > 0) {
                        for (Service_Request_Line_Item__c srd : srAndSRDListMap.get(srId)) {
                            if (srd.Status__c == Constants.SRD_STATUS_COMPLETE) {
                                if (srd.Reason_Code__c != Constants.SRD_RESULT_CANCEL) {
                                    if (srdCompleteMap.containsKey(srd.Service_Request__c)) {
                                        srdCompleteMap.get(srd.Service_Request__c).add(true);
                                    } else {
                                        srdCompleteMap.put(srd.Service_Request__c, new List<Boolean>{true});
                                    }
                                }
                            } else {
                                if (srdCompleteMap.containsKey(srd.Service_Request__c)) {
                                    srdCompleteMap.get(srd.Service_Request__c).add(false);
                                } else {
                                    srdCompleteMap.put(srd.Service_Request__c, new List<Boolean>{false});
                                }
                            }
                        }
                    }

                    Boolean isSRDCompleted = true;
                    if (srdCompleteMap != null && srdCompleteMap.size() > 0) {
                        List<Boolean> compBol = srdCompleteMap.get(srId);
                        for (Boolean isCmp : compBol) {
                            isSRDCompleted = isSRDCompleted && isCmp;
                        }
                    }
                    Service_Request__c sr = new Service_Request__c();
                    Service_Request_Line_Item__c srd = new Service_Request_Line_Item__c();
                    sr.Id = srId;
                    if (isSRDocumentDelivery == true && docDeliveryStatus) {
                        sr.Document_Delivery_Status__c = 'Success';
                    } else if (isSRDocumentDelivery == false && docDeliveryStatus) {
                        sr.Document_Delivery_Status__c = 'Failed';
                    }
                    if (isSRDDocumentDelivery && isSRDCompleted) {
                        sr.Status__c = 'Complete';
                    }
                    srList.add(sr);
                }
            }

            if (srList != null && srList.size() > 0) {
                try {
                    update srList;
                    System.debug('Service Requests updated successfully');
                } catch (Exception ex) {
                    GDSException.LogException(ex);
                    System.debug('Error updating Service Requests: ' + ex.getMessage());
                }

            }
        }

        if (caseActionResultList != null && caseActionResultList.size() > 0) {
            try {
                manageCaseActionResults.createActionResultList(caseActionResultList);
                System.debug('Case Action Results created successfully');
            } catch (Exception ex) {
                GDSException.LogException(ex);
                System.debug('Error creating Case Action Results: ' + ex.getMessage());
            }
        }
    }

    public static void updateServiceRequest(Map<Id, Service_Request_Document__c> triggerOldMap, List<Service_Request_Document__c> triggerNew) {
        Set<Id> srdids = new Set<Id>();
        Map<Id, Service_Request_Line_Item__c> srdDetails = new Map<Id, Service_Request_Line_Item__c>();
        for (Service_Request_Document__c rpdoc : triggerNew) {
            if (rpdoc.Service_Request_Line_Item__c != null && triggerOldMap.get(rpdoc.Id).Service_Request_Line_Item__c != rpdoc.Service_Request_Line_Item__c) {
                srdids.add(rpdoc.Service_Request_Line_Item__c);
            }
        }
        if (srdids != null && srdids.size() > 0) {
            srdDetails = SRLineItemQueryselector.getServiceRequestDetaillist(srdids);
        }
        if (srdDetails != null && srdDetails.size() > 0) {
            for (Service_Request_Document__c rpdoc : triggerNew) {
                rpdoc.Service_Request__c = srdDetails.get(rpdoc.Service_Request_Line_Item__c).Service_Request__c;
                rpdoc.Status__c = Constants.RPD_STATUS;
                rpdoc.Intake_Request__c = srdDetails.get(rpdoc.Service_Request_Line_Item__c).Service_Request__r.Intake_Request__c;
            }
        }
    }

    public static void CreateReviewTaskOnServiceRequest(Map<Id, Service_Request_Document__c> triggerOldMap, List<Service_Request_Document__c> triggerNew) {
        Set<Id> srids = new Set<Id>();
        Set<Id> createTasksrids = new Set<Id>();
        Map<Id, Task> Activefollowuptasks = new Map<Id, Task>();
        try {
            for (Service_Request_Document__c rpd : triggerNew) {
                if (rpd.Service_Request_Line_Item__c != null && triggerOldMap.get(rpd.Id).Service_Request_Line_Item__c != rpd.Service_Request_Line_Item__c
                        && rpd.Status__c == Constants.RPD_STATUS) {
                    srids.add(rpd.Service_Request__c);
                }
            }
            if (srids != null && srids.size() > 0) {
                Activefollowuptasks = TaskQuerySelector.getActiveProcessTask(srids);
                for (Id srid : srids) {
                    if (!Activefollowuptasks.containsKey(srid)) {
                        createTasksrids.add(srid);
                    }
                }
            }
            if (createTasksrids != null && createTasksrids.size() > 0) {
                TaskUtility.CreateTask(createTasksrids, Constants.TASKTYPE_REVIEW);
                System.debug('Review tasks created successfully');
            }
        } catch (Exception e) {
            GDSException.LogException(e);
            System.debug('Error creating Review tasks: ' + e.getMessage());
        }
    }

    public static void CreateReviewTaskOnServiceRequestDetails(Map<Id, Service_Request_Document__c> triggerOldMap, List<Service_Request_Document__c> triggerNew) {
        Set<Id> srdids = new Set<Id>();
        Set<Id> srids = new Set<Id>();
        Map<Id, Service_Request_Line_Item__c> srdmap = new Map<Id, Service_Request_Line_Item__c>();
        List<Service_Request_Line_Item__c> srdlist = new List<Service_Request_Line_Item__c>();
        try {
            for (Service_Request_Document__c rpd : triggerNew) {
                if (rpd.Service_Request_Line_Item__c != null && triggerOldMap.get(rpd.Id).Service_Request_Line_Item__c != rpd.Service_Request_Line_Item__c
                        && rpd.Status__c == Constants.RPD_STATUS) {
                    srdids.add(rpd.Service_Request_Line_Item__c);
                    srids.add(rpd.Service_Request__c);
                }
            }
            if (srdids != null && srdids.size() > 0) {
                srdmap = SRLineItemQueryselector.getServiceRequestDetaillist(srdids);
                Map<Id, Task> ActiveReviewtaskmap = TaskQuerySelector.getActiveProcessTask(srids);
                if (srdmap != null && srdmap.size() > 0) {
                    for (Service_Request_Document__c rpdDetails : triggerNew) {
                        if (srdmap.containsKey(rpdDetails.Service_Request_Line_Item__c)) {
                            if (srdmap.get(rpdDetails.Service_Request_Line_Item__c).Status__c != Constants.SRD_STATUS_COMPLETE) {
                                Service_Request_Line_Item__c srd = new Service_Request_Line_Item__c();
                                srd.Id = rpdDetails.Service_Request_Line_Item__c;
                                if (ActiveReviewtaskmap.containsKey(rpdDetails.Service_Request__c)) {
                                    if (!(ActiveReviewtaskmap.get(rpdDetails.Service_Request__c).Is_Owner_A_Queue__c)) {
                                        srd.Status__c = Constants.SRD_STATUS_QA_IN_PROGRESS;
                                    } else {
                                        srd.Status__c = Constants.SRD_STATUS_DOCUMENTS_RECEIVED;
                                    }
                                } else {
                                    srd.Status__c = Constants.SRD_STATUS_DOCUMENTS_RECEIVED;
                                }
                                srdlist.add(srd);
                            }
                        }
                    }
                }
                if (srdlist != null && srdlist.size() > 0) {
                    try {
                        update srdlist;
                        System.debug('Service Request Line Items updated successfully');
                    } catch (Exception ex) {
                        GDSException.LogException(ex);
                        System.debug('Error updating Service Request Line Items: ' + ex.getMessage());
                    }
                }
            }
        } catch (Exception e) {
            GDSException.LogException(e);
            System.debug('Error creating Review tasks on Service Request Details: ' + e.getMessage());
        }

    }

    public static void SendDoctoCase360SRDcomplete(Map<Id, Service_Request_Document__c> triggerOldMap, List<Service_Request_Document__c> triggerNew) {
        Set<Id> srdids = new Set<Id>();
        Set<Id> srdIdset = new Set<Id>();
        Map<Id, Service_Request_Line_Item__c> srdDetails = new Map<Id, Service_Request_Line_Item__c>();
        for (Service_Request_Document__c rpdoc : triggerNew) {
            if (rpdoc.Service_Request_Line_Item__c != null && triggerOldMap.get(rpdoc.Id).Service_Request_Line_Item__c != rpdoc.Service_Request_Line_Item__c) {
                srdids.add(rpdoc.Service_Request_Line_Item__c);
            }
        }
        if (srdids != null && srdids.size() > 0) {
            srdDetails = SRLineItemQueryselector.getServiceRequestDetaillist(srdids);
        }
        if (srdDetails != null && srdDetails.size() > 0) {
            for (Service_Request_Line_Item__c srd : srdDetails.values()) {
                if (srd.Status__c == Constants.SRD_STATUS_COMPLETE) {
                    srdIdset.add(srd.Id);
                }
            }
        }
        System.debug('srdIdset--' + srdIdset);
        if (srdIdset != null && srdIdset.size() > 0) {
            try {
                ServiceRequestDetailService.addSendDocumentsToCase360IntegrationRequest(srdIdset);
                System.debug('Documents sent to Case360 for SRD complete');
            } catch (Exception ex) {
                GDSException.LogException(ex);
                System.debug('Error sending documents to Case360 for SRD complete: ' + ex.getMessage());
            }
        }
    }
}