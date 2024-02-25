public with sharing class TaskUtility {
    public static Id FollowupRecordtypeId = RecordTypeUtil.getRecordTypeId(Task.SObjectType, Constants.FOLLOWUP_RECORDTYPE  , false);
    public static Id ReviewRecordtypeId = RecordTypeUtil.getRecordTypeId(Task.SObjectType, Constants.QA_REVIEW_RECORDTYPE  , false);
    
    public static void CreateTask(set<Id> relatedObjids,string Tasktype, string recurrenceInterval, DateTime endDate){
        list<Task> newFollowupTask= new list<Task>();
        BusinessDaysUtility bdu = new BusinessDaysUtility();
        map<Id,Service_Request__c> srMap = new map<Id,Service_Request__c>();
        map<id,Service_Request_Fax_job__c> RightfaxDetailMap = new map<id,Service_Request_Fax_job__c>();
        map<Id,Service_Request_Document__c> rpdDetailMap = new map<Id,Service_Request_Document__c>();
        map<Id,Service_Request_Line_Item__c> srdMap = new map<Id,Service_Request_Line_Item__c>();
        Map<string,Task_Configuration__mdt> taskmdtMap = new Map<string,Task_Configuration__mdt>();
        Id Followupqueueid;
        Id Reviewqueueid;
        Id CoversheetFailurequeueid;
        Id TaskOwnerId;
        Id taskrecordtypeId;
        if(Tasktype == Constants.TASKTYPE_FOLLOWUP){
            srMap = ServiceRequestQuerySelector.getServiceRequestMap(relatedObjids);
            RightfaxDetailMap = ServiceRequestQuerySelector.getSRRightfaxjobDetails(relatedObjids);
            Followupqueueid= CaseQuerySelector.getQueueId(Constants.SERVICEREQUEST_FOLLOWUP_QUEUE);
            taskmdtMap = TaskQuerySelector.gettasktypeconfigDetails(new set<string>{Constants.TASKTYPE_FOLLOWUP}); 
            TaskOwnerId=Followupqueueid;
            taskrecordtypeId = FollowupRecordtypeId; 
        }
        else if(Tasktype == Constants.TASKTYPE_REVIEW){
            srMap = ServiceRequestQuerySelector.getServiceRequestMap(relatedObjids);
            srdMap = SRLineItemQueryselector.getServiceRequestDetaillist(relatedObjids);
            rpdDetailMap = SRLineItemQueryselector.getRPDDetaillist(relatedObjids);
            Reviewqueueid= CaseQuerySelector.getQueueId(Constants.SERVICEREQUEST_REVIEW_QUEUE);
            taskmdtMap = TaskQuerySelector.gettasktypeconfigDetails(new set<string>{Constants.TASKTYPE_REVIEW});
            TaskOwnerId=Reviewqueueid;
            taskrecordtypeId = ReviewRecordtypeId; 
        }
        else if(Tasktype == Constants.TASKTYPE_FAX_FAILED){
            srMap = ServiceRequestQuerySelector.getServiceRequestMap(relatedObjids);
            RightfaxDetailMap = ServiceRequestQuerySelector.getSRRightfaxjobDetails(relatedObjids);
            CoversheetFailurequeueid = CaseQuerySelector.getQueueId(Constants.COVERSHEETFAXFAILURE_FOLLOWUP_QUEUE);
            taskmdtMap = TaskQuerySelector.gettasktypeconfigDetails(new set<string>{Constants.TASKTYPE_FAX_FAILED});
             TaskOwnerId= CoversheetFailurequeueid;
            taskrecordtypeId = FollowupRecordtypeId; 
        }
        try{
            for(Id objid: relatedObjids){
                if(srMap.get(objid).Status__c!=Constants.SR_STATUS_COMPLETE){
                    for(Task_Configuration__mdt taskconfig:taskmdtMap.values()){
                        Task objTask = new Task();
                        objTask.RecordTypeId = taskrecordtypeId;
                        objTask.Task_Type__c = taskconfig.Task_Type__c;
                        objTask.WhatId = objid;
                        objTask.RecurrenceInterval__c = recurrenceInterval;
                        objTask.EndDate__c = endDate;
                        objTask.JobId__c = String.valueOf(System.currentTimeMillis());
                        
                        // Rest of the code remains the same...
                        
                        newFollowupTask.add(objTask);
                    }
                }
            }
            if(newFollowupTask!= null && newFollowupTask.size()>0)
                insert newFollowupTask;
        }catch(Exception e){
            GDSException.LogException(e);
        } 
    }
    public static list<Service_Request_Line_Item__c>  UpdateAllServiceRequestDetailStatus(list<Service_Request_Line_Item__c> SRDlist){
        list<Service_Request_Line_Item__c> updateSRDlist= new list<Service_Request_Line_Item__c>();
        for(Service_Request_Line_Item__c SRDetails: SRDlist){
            if(SRDetails.Status__c != constants.SRD_STATUS_COMPLETE){
                SRDetails.Status__c = constants.SRD_STATUS_COMPLETE;
                if(SRDetails.Reason_Code__c == null || SRDetails.Reason_Code__c==''){
                    SRDetails.Reason_Code__c = Constants.SRD_RESULT_NO_RECORDS;       
                }
                updateSRDList.add(SRDetails);
            }
        }	
        return updateSRDlist;
    }
} 
