public class ServiceRequestLineItemRecsController {
/************************************************************
* @File Name          : ServiceRequestLineItemRecsController
* @Description        : 
* @Author             : AppShark Team
* @Created Date       : 
* @Last Updated Date  : 
**********************************************************/
    @AuraEnabled(cacheable=true)
    public static list<Service_Request_Line_Item__c> getServiceRequestDetailrecords(Id taskid){
        Task TaskDtls= TaskQuerySelector.getTaskdetails(taskid);
        list<Service_Request_Line_Item__c> srdlist= new list<Service_Request_Line_Item__c>();
        if(TaskDtls!=null &&TaskDtls.WhatId!=null){
            srdlist=SRLineItemQueryselector.getrelatedServiceReqDetails(new set<id>{TaskDtls.WhatId}).get(TaskDtls.WhatId);
        }
        
        return srdlist;
    }
    
    @AuraEnabled(cacheable=true)
    public static list<Service_Request_Document__c> getRPDrecords(Id recid){ 
        String sObjName = recid.getSObjectType().getDescribe().getName();
        list<Service_Request_Document__c> rpdlist= new list<Service_Request_Document__c>();
        if(sObjName=='Task'){
            system.debug('taskid'+recid);
            Task TaskDtls= TaskQuerySelector.getTaskdetails(recid);
            if(TaskDtls!=null &&TaskDtls.WhatId!=null){
                rpdlist=ServiceRequestQuerySelector.getRPDlistmapWithSR(new set<id>{TaskDtls.WhatId}).get(TaskDtls.WhatId);
            }
        }else if(sObjName==constants.OBJECT_NAME_SRD){
            set<Id> srdids=new set<Id>();
            srdids.add(recid);
            rpdlist=SRLineItemQueryselector.getRPDlistmapWithSRD(srdids).get(recid);
        }
        return rpdlist;
    }
    
    @AuraEnabled
    public static void updateRPDStatus(list<string> rpdids, string status){                
        list<Service_Request_Document__c> updaterpdlist= new list<Service_Request_Document__c>();
        for(Service_Request_Document__c rpd : [SELECT Id, Status__c, Is_Reviewed__c, Reviewed_Date_Time__c 
                                                 FROM Service_Request_Document__c
                                                 WHERE Id IN :rpdids])
        {
            rpd.Is_Reviewed__c = true;
            rpd.Reviewed_Date_Time__c = System.now();
            if(status == 'Archived')
                rpd.Status__c = 'Archived';
            updaterpdlist.add(rpd);
        }
        if(updaterpdlist != null && updaterpdlist.size() > 0){
            update updaterpdlist;
        }
    }
    
    @AuraEnabled
    public static void updateServiceRequestDocument(Service_Request_Document__c updatedDocument){
        Service_Request_Document__c existingDocument = [SELECT Id, Name, Description__c, Status__c 
                                                       FROM Service_Request_Document__c 
                                                       WHERE Id = :updatedDocument.Id];
        existingDocument.Name = updatedDocument.Name;
        existingDocument.Description__c = updatedDocument.Description__c;
        existingDocument.Status__c = updatedDocument.Status__c;
        
        update existingDocument;
    }
}