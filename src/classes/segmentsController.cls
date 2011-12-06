/*
Copyright (c) 2011, salesforce.com, Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, 
are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, 
    this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, 
    this list of conditions and the following disclaimer in the documentation 
    and/or other materials provided with the distribution.
    * Neither the name of the salesforce.com, Inc. nor the names of its contributors 
    may be used to endorse or promote products derived from this software 
    without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED 
OF THE POSSIBILITY OF SUCH DAMAGE.

*/
public with sharing class segmentsController {
    public String stringSegments {get; set;}
    Integer numberOfSegments {get; set;}
    
    public Boolean showSegmentsPicker {get; set;}
    public Boolean showSegmentCreator {get; set;}
    public Boolean showBatchInfo {get; set;}
    public Boolean keepOriginal {get; set;}
    
    public List<Segment> listOfSegments  {get; set;}
    public Integer MAX_SEGMENTS = 25;
    public Integer memberCount {get; set;}
    public Campaign parentCampaign {get; set;}
    public Integer MAX_SYNCHRONOUS_MEMBERS {get; set;}  
    public String batchEmailNotification {get; set;}
    
    List<Campaign> listOfCampaigns = new List<Campaign>();  
    List<Integer> targetMemberCount = new List<Integer>();
    List<Integer> membersAdded = new List<Integer>();   
    Id parentCampaignId;    
    Integer targetForEachCampaign; 
    Integer remainderMembers;
    Integer submittedMemberCount;
    Boolean success;
    Integer CONCURRENT_BATCH_LIMIT = 5;//at time of coding, there are at most 5 concurrent batch apex jobs in any org
        
    List<CampaignMember> newCampaignMembers = new List<CampaignMember>();
    
    
    public class segment{
        public Campaign campaign {get; set;}
        public Integer membercount;
        public Integer targetMemberCount {get; set;}
        public void setTargetMemberCount(Integer value){
            targetMemberCount = value;
            targetMemberPercentage = (value/memberCount)*100;
        }
        public Integer targetMemberPercentage {get; set;}
        public Integer membersAdded {get; set;}
    }
    
    
    public segmentsController(ApexPages.StandardController stdController){
        parentCampaign = (Campaign)stdController.getRecord();
        parentCampaign = [select id,name,NumberOfContacts, NumberOfLeads,type,status,startDate,endDate from campaign where id=:parentCampaign.id];
        memberCount = parentCampaign.NumberOfContacts + parentCampaign.NumberOfLeads;
        showSegmentsPicker = true;
        showBatchInfo = false;
        MAX_SYNCHRONOUS_MEMBERS = 4000;
        
        if(memberCount==0){
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,'Please add members to this Campaign before creating segments.'));
            showSegmentsPicker = false;
            showSegmentCreator = false;         
        }
    }
    
    public void setSegments(){

        if(pattern.matches('^[0-9]+$',stringSegments)){
            numberOfSegments = Integer.valueOf(stringSegments);
            targetForEachCampaign = Math.floor(memberCount/numberOfSegments).intValue();
            remainderMembers = memberCount - (targetForEachCampaign*numberOfSegments);
            
            listOfSegments = new List<Segment>();
            if(numberOfSegments>0 && numberOfSegments<= MAX_SEGMENTS){
                showSegmentsPicker = false;
                showSegmentCreator = true;
                //create the segments
                //create destination campaigns
            
                for(Integer segment=0; segment<numberOfSegments;segment++){
                    Segment newSegment = new Segment();
                    Campaign newSegmentCampaign = parentCampaign.clone(false,true);
                    newSegmentCampaign.Name = parentCampaign.Name + ' - segment ' + (segment+1);
                    newSegmentCampaign.ParentId = parentCampaign.Id;
                    newSegment.campaign = newSegmentCampaign;
                    newSegment.memberCount = memberCount;
                    if(segment<(numberOfSegments-1)){
                        newSegment.setTargetMemberCount(targetForEachCampaign);
                        
                    } else {
                        newSegment.setTargetMemberCount(targetForEachCampaign+remainderMembers);
                    }
                   
                    newSegment.membersAdded = 0;
                    listOfSegments.add(newSegment);
                }
                
                
            } else {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,'Please pick a number larger than 0 and smaller than '+MAX_SEGMENTS+'.'));
                
            }

        } else {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,'Please enter a valid number'));
        }
    }
    
    public void resetSegments(){
        numberOfSegments=null;
        showSegmentsPicker=true;
        showSegmentCreator=false;
    }
    
    public PageReference runSegments(){
        
        submittedMemberCount = 0;
        
        List<Integer> segmentSizes = new List<Integer>();
        List<Integer> membersAdded = new List<Integer>();
        listOfCampaigns.clear();
        
        for(segment thisSegment : listOfSegments){
            listOfCampaigns.add(thisSegment.campaign);
            segmentSizes.add(thisSegment.targetMemberCount);
            submittedMemberCount += thisSegment.targetMemberCount;
            membersAdded.add(0);
        }
        
        //check to make sure user submitted count is right
        if(submittedMemberCount==memberCount){
            
            try {
                insert listOfCampaigns;
            } catch (exception e) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,'There was an error creating the segment Campaigns: ' + e.getMessage() ));
                return null;
            }
            
            //insert campaign statuses
            //assume sent and responded are there, as they will be created in the new campaigns
            List<CampaignMemberStatus> statuslist = [SELECT Id, CampaignId, HasResponded, Label, IsDefault,SortOrder from CampaignMemberStatus WHERE CampaignId = :parentCampaign.id and label <> 'Sent' and label <> 'Responded'];
            List<CampaignMemberStatus> newStatuses = new List<CampaignMemberStatus>();
            for(Campaign thisSegmentCampaign : listOfCampaigns){
                for(CampaignMemberStatus thisStatus : statuslist){
                    CampaignMemberStatus sclone = thisStatus.clone(false);
                    sclone.CampaignId = thisSegmentCampaign.Id;
                    newStatuses.add(sclone);
                }
            }
            try {
                insert newStatuses;
            } catch (exception e) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,'There was an error copying statuses: ' + e.getMessage() ));
                return null;
            }
            
            List<Id> newCampaignIds = new List<Id>();
            
            for(Campaign myCamp : listOfCampaigns){
                newCampaignIds.add(myCamp.Id);
            }
            
            //add chatter message to the parent campaign\
            /*
            try {
		        FeedPost fpost = new FeedPost();
		        fpost.ParentId = parentCampaign.id;
		        fpost.Body = 'The Campaign Segmentation Wizard was run, creating ' + listOfSegments.size() + ' segments.';
		        insert fpost;
  			} catch (exception e) {
            	system.debug('Chatter feeds aren\'t enabled on Campaigns. Enable Chatter feeds on Campaigns to automatically record when the Campaign Segementation Wizard is run.');
            }
            */
            success = false;
            if(membercount<=MAX_SYNCHRONOUS_MEMBERS){
                success = memberAssignment.assignMembersNow(parentCampaign.Id,newCampaignIds,segmentSizes,membersAdded,keepOriginal);
            } else {
                
                List<AsyncApexJob> numBatchJobs = [SELECT Id, Status FROM AsyncApexJob WHERE Status = 'Queued' OR Status = 'Processing'];
                if((CONCURRENT_BATCH_LIMIT - numBatchJobs.size())>0){
                
                    User thisUser = [select email from User where id = :UserInfo.getUserId()];
                    batchEmailNotification = thisUser.email;
                    batchSegmentCreator batchSegments = new batchSegmentCreator();
                    batchSegments.query='select id,campaignId, leadId, contactid from campaignMember where CampaignId = \'' +  parentCampaign.Id + '\''; 
                    batchSegments.parentCampaignId = parentCampaign.Id;
                    batchSegments.segmentCampaignIds = newCampaignIds;
                    batchSegments.segmentSizes = segmentSizes;
                    batchSegments.membersAdded = membersAdded;
                    batchSegments.keepOriginal = keepOriginal;
                    batchSegments.email = batchEmailNotification;
                    ID batchprocessid = Database.executeBatch(batchSegments);
                    
                    showSegmentCreator = false;
                    showBatchInfo = true;
                    
                    return null;
                } else {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,'There are currently ' + numBatchJobs.size() + ' Apex jobs scheduled. Try again later.'));
                    return null;
                }
            }
        
            PageReference pageRef = new PageReference('/' + parentCampaign.Id);
            pageRef.setRedirect(true);
            return pageRef;
        } else {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,'Please make sure your segment member counts add up to the total member count.'));
            return null;
        }
        
    }
    
    public PageReference cancel(){
            PageReference pageRef = new PageReference('/' + parentCampaign.Id);
            pageRef.setRedirect(true);
            return pageRef;
        }
    
    static testMethod void segmentation() {
        
        String stringSegments = '3';
        Integer segments = 3;
        Integer contacts = 10;
        //create a campaign
        Campaign parentCampaign = new Campaign(
            name='Parent for test',
            IsActive=true
        );
        
        insert parentCampaign;
        
        List<Contact> newContacts = new List<Contact>();
        
        
        //create 10 contacts
        for (Integer contactNumber=0; contactNumber<contacts;contactNumber++){
            Contact thisContact = new Contact(
                LastName='test' + contactNumber
            );
            newContacts.add(thisContact);
        }
        insert newContacts;
        
        List<CampaignMember> myCampaignMembers = new List<CampaignMember>();
        
        //add them to campaign
        for(contact thisContact : newContacts){
            CampaignMember thisCM = new CampaignMember(
                CampaignId=parentCampaign.Id,
                ContactId = thisContact.Id
            );
            myCampaignMembers.add(thisCM);
                    
        }
        
        insert myCampaignMembers;
        
         Test.setCurrentPageReference(new PageReference('Page.segments'));
         
         ApexPages.StandardController sc = new ApexPages.standardController(parentCampaign);
        //pass the controller into the extension
        segmentsController ext = new segmentsController(sc); 
        ext.stringSegments = stringSegments;
        ext.setSegments();
        
        ext.listOfSegments[0].targetMemberCount = 1;
        ext.listOfSegments[1].targetMemberCount = 2;
        ext.listOfSegments[2].targetMemberCount = 7;
        ext.keepOriginal = false;
        Test.startTest();
        ext.runSegments();
        Test.stopTest();
        List<Campaign> createdCampaigns = [select id,NumberOfContacts from Campaign where ParentId = :parentCampaign.id order by Name];
        Campaign parentCampaignAfter = [select NumberOfContacts from Campaign where Id=:parentCampaign.Id];
        
        System.assertEquals(segments,createdCampaigns.size());
        System.assert(createdCampaigns[0].NumberOfContacts==1);
        System.assert(createdCampaigns[1].NumberOfContacts==2);
        System.assert(createdCampaigns[2].NumberOfContacts==7);
        System.assertEquals(contacts,createdCampaigns[0].NumberOfContacts + createdCampaigns[1].NumberOfContacts + createdCampaigns[2].NumberOfContacts);
        System.assertEquals(0,parentCampaignAfter.NumberOfContacts);
        
    }
    
    static testMethod void BIGsegmentation() {
        
        String stringSegments = '3';
        Integer segments = 3;
        Integer contacts = 200;
        //create a campaign
        Campaign parentCampaign = new Campaign(
            name='Parent for test',
            IsActive=true
        );
        
        insert parentCampaign;
        
        List<Contact> newContacts = new List<Contact>();
        
        
        //create contacts
        for (Integer contactNumber=0; contactNumber<contacts;contactNumber++){
            Contact thisContact = new Contact(
                LastName='test' + contactNumber
            );
            newContacts.add(thisContact);
        }
        insert newContacts;
        
        List<CampaignMember> myCampaignMembers = new List<CampaignMember>();
        
        //add them to campaign
        for(contact thisContact : newContacts){
            CampaignMember thisCM = new CampaignMember(
                CampaignId=parentCampaign.Id,
                ContactId = thisContact.Id
            );
            myCampaignMembers.add(thisCM);
                    
        }
        
        insert myCampaignMembers;
        
         Test.setCurrentPageReference(new PageReference('Page.segments'));
         
         ApexPages.StandardController sc = new ApexPages.standardController(parentCampaign);
        //pass the controller into the extension
        segmentsController ext = new segmentsController(sc); 
        ext.stringSegments = stringSegments;
        ext.MAX_SYNCHRONOUS_MEMBERS = 200;
        ext.setSegments();
        ext.keepOriginal = false;
        
        ext.listOfSegments[0].targetMemberCount = 20;
        ext.listOfSegments[1].targetMemberCount = 100;
        ext.listOfSegments[2].targetMemberCount = 80;
        Test.startTest();
        ext.runSegments();
        Test.stopTest();
        List<Campaign> createdCampaigns = [select id,NumberOfContacts from Campaign where ParentId = :parentCampaign.id order by Name];
        Campaign parentCampaignAfter = [select NumberOfContacts from Campaign where Id=:parentCampaign.Id];
        
        System.assertEquals(segments,createdCampaigns.size());
        System.assert(createdCampaigns[0].NumberOfContacts==20);
        System.assert(createdCampaigns[1].NumberOfContacts==100);
        System.assert(createdCampaigns[2].NumberOfContacts==80);
        System.assertEquals(contacts,createdCampaigns[0].NumberOfContacts + createdCampaigns[1].NumberOfContacts + createdCampaigns[2].NumberOfContacts);
        System.assertEquals(0,parentCampaignAfter.NumberOfContacts);
        
    }
    
    static testMethod void noMembers() {
        
        //create a campaign
        Campaign parentCampaign = new Campaign(
            name='Parent for test',
            IsActive=true
        );
        
        insert parentCampaign;
        
         Test.setCurrentPageReference(new PageReference('Page.segments'));
         
         ApexPages.StandardController sc = new ApexPages.standardController(parentCampaign);
        //pass the controller into the extension
        segmentsController ext = new segmentsController(sc); 
        
        
        System.assertEquals(false,ext.showSegmentsPicker);
        System.assertEquals(false,ext.showSegmentCreator);
        
        
    }
    
    static testMethod void tooManySegments() {
        String stringSegments = '300';
        Integer segments = 300;
        Integer contacts = 10;
        //create a campaign
        Campaign parentCampaign = new Campaign(
            name='Parent for test',
            IsActive=true
        );
        
        insert parentCampaign;
        
        List<Contact> newContacts = new List<Contact>();
        
        
        //create 10 contacts
        for (Integer contactNumber=0; contactNumber<contacts;contactNumber++){
            Contact thisContact = new Contact(
                LastName='test' + contactNumber
            );
            newContacts.add(thisContact);
        }
        insert newContacts;
        
        List<CampaignMember> myCampaignMembers = new List<CampaignMember>();
        
        //add them to campaign
        for(contact thisContact : newContacts){
            CampaignMember thisCM = new CampaignMember(
                CampaignId=parentCampaign.Id,
                ContactId = thisContact.Id
            );
            myCampaignMembers.add(thisCM);
                    
        }
        
        insert myCampaignMembers;
        
         Test.setCurrentPageReference(new PageReference('Page.segments'));
         
         ApexPages.StandardController sc = new ApexPages.standardController(parentCampaign);
        //pass the controller into the extension
        segmentsController ext = new segmentsController(sc); 
        ext.stringSegments = stringSegments;
        ext.setSegments();
        
        system.assertEquals(0,ext.listOfSegments.size());       
    }
    
    static testMethod void memberStatusCloning() {
        String stringSegments = '3';
        Integer segments = 3;
        Integer contacts = 10;
        //create a campaign
        Campaign parentCampaign = new Campaign(
            name='Parent for test',
            IsActive=true
        );
        
        insert parentCampaign;
        
        insert new CampaignMemberStatus(CampaignId = parentCampaign.Id,Label = 'NewStatus', HasResponded=true,SortOrder=10);
                
        List<Contact> newContacts = new List<Contact>();
        
        
        //create 10 contacts
        for (Integer contactNumber=0; contactNumber<contacts;contactNumber++){
            Contact thisContact = new Contact(
                LastName='test' + contactNumber
            );
            newContacts.add(thisContact);
        }
        insert newContacts;
        
        List<CampaignMember> myCampaignMembers = new List<CampaignMember>();
        
        //add them to campaign
        for(contact thisContact : newContacts){
            CampaignMember thisCM = new CampaignMember(
                CampaignId=parentCampaign.Id,
                ContactId = thisContact.Id
            );
            myCampaignMembers.add(thisCM);
                    
        }
        
        insert myCampaignMembers;
        
         Test.setCurrentPageReference(new PageReference('Page.segments'));
         
         ApexPages.StandardController sc = new ApexPages.standardController(parentCampaign);
        //pass the controller into the extension
        segmentsController ext = new segmentsController(sc); 
        ext.stringSegments = stringSegments;
        ext.setSegments();
        
        ext.listOfSegments[0].targetMemberCount = 1;
        ext.listOfSegments[1].targetMemberCount = 2;
        ext.listOfSegments[2].targetMemberCount = 7;
        
        ext.runSegments();
        List<Campaign> createdCampaigns = [select id,NumberOfContacts from Campaign where ParentId = :parentCampaign.id order by Name];
        Campaign parentCampaignAfter = [select NumberOfContacts from Campaign where Id=:parentCampaign.Id];
        
        List<CampaignMemberStatus> statusesOnParent = [SELECT Id, CampaignId, HasResponded, Label, IsDefault,SortOrder from CampaignMemberStatus WHERE CampaignId = :parentCampaign.id];
        
        List<CampaignMemberStatus> statusesOnChildren = [SELECT Id, CampaignId, HasResponded, Label, IsDefault,SortOrder from CampaignMemberStatus WHERE CampaignId IN (select id from Campaign where ParentId = :parentCampaign.id)];
        
        System.assertEquals(3,statusesOnParent.size());
        System.assertEquals(9,statusesOnChildren.size());
        
    }
    
    static testMethod void UICalcs() {
        String stringSegments = '3';
        Integer segments = 3;
        Integer contacts = 10;
        //create a campaign
        Campaign parentCampaign = new Campaign(
            name='Parent for test',
            IsActive=true
        );
        
        insert parentCampaign;
        
        List<Contact> newContacts = new List<Contact>();
        
        
        //create 10 contacts
        for (Integer contactNumber=0; contactNumber<contacts;contactNumber++){
            Contact thisContact = new Contact(
                LastName='test' + contactNumber
            );
            newContacts.add(thisContact);
        }
        insert newContacts;
        
        List<CampaignMember> myCampaignMembers = new List<CampaignMember>();
        
        //add them to campaign
        for(contact thisContact : newContacts){
            CampaignMember thisCM = new CampaignMember(
                CampaignId=parentCampaign.Id,
                ContactId = thisContact.Id
            );
            myCampaignMembers.add(thisCM);
                    
        }
        
        insert myCampaignMembers;
        
         Test.setCurrentPageReference(new PageReference('Page.segments'));
         
         ApexPages.StandardController sc = new ApexPages.standardController(parentCampaign);
        //pass the controller into the extension
        segmentsController ext = new segmentsController(sc); 
        ext.stringSegments = stringSegments;
        ext.setSegments();
        ext.resetSegments();
        ext.stringSegments = stringSegments;
        ext.setSegments();
        system.assertEquals(3,ext.listOfSegments.size());   
        ext.listOfSegments[0].targetMemberCount = 1;
        ext.listOfSegments[1].targetMemberCount = 2;
        ext.listOfSegments[2].targetMemberCount = 7;
        
        ext.cancel();

    }
    
}