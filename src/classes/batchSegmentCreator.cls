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
gglobal class batchSegmentCreator implements Database.Batchable<SObject>,Database.Stateful{
	global String query;
	global String email;
	global Id parentCampaignId;
	global List<Id> segmentCampaignIds;
	global List<Integer> segmentSizes;
	global List<Integer> membersAdded;
	global List<Double> sizesCDF;
	global String errorTxt = '';
	global boolean keepOriginal;
	
	global database.querylocator start(Database.BatchableContext BC){
	            return Database.getQueryLocator(query);}
	
	global void execute(Database.BatchableContext BC, List<sObject> scope){
		//Old code from AppEx
		/*
		boolean thisBatchSuccess = memberAssignment.assignMembersNow(parentCampaignId,segmentCampaignIds,segmentSizes,membersAdded);
	    if(!thisBatchSuccess){
	    	success = false;
	    }
	    */
	    
	    List<CampaignMember> newCampaignMembers = new List<CampaignMember>();
	    
	    for(sObject s : scope){
	    	
	    	CampaignMember oldCM = (CampaignMember)s;
	    	
	    	Boolean assigned = false;
	    	
	    	while(assigned == false){
	    		Integer assignedList;
	    		Double prob = Math.Random();
	    		
	    		// iterate through sizesCDF to find correct bucket
	    		// note that sizesCDF must be sorted from smallest to largest
	    		// probability (and should be given the generation process above)
	    		for (Integer i=0; i<sizesCDF.size(); i++) {
	    			if (sizesCDF[i] >= prob) {
	    				assignedList = i;
	    				break;
	    			}
	    		}

				if((membersAdded[assignedList] < segmentSizes[assignedList])){		    
					 newCampaignMembers.add(
					 	new CampaignMember(
							CampaignId = segmentCampaignIds[assignedList],
							LeadId = oldCM.LeadId,
							ContactId = oldCM.ContactId		
					 	)
					 );
					 assigned = true;
					 
					 membersAdded[assignedList]++;
					 
				}
	    	}	
 	
	    }
	    
	    if(!newCampaignMembers.isEmpty()){
	    	Database.saveresult[] srList = database.insert(newCampaignMembers,false);
	    	
	    	List<CampaignMember> deleteMe = new List<CampaignMember>();
	    	for(Integer i = 0;i<srList.size();i++){
	    		Database.saveresult sr = srList[i];
	    		
	    		if(sr.isSuccess() && !keepOriginal){
	    			deleteMe.add( (CampaignMember)scope[i] );
	    		}
	    		else{
	    			for(Database.Error e : sr.getErrors()){
	    				errorTxt = errorTxt + 'Original Record Id:' + scope[i].get('Id') + '\n' + 'Error:' + e.getMessage() + '\n\n';
	    			}
	    			
	    		}
	    	}
	    	
	    	if(!deleteMe.isEmpty()){
	    		delete deleteMe;
	    	}
	    
	    }
	    
	}
	global void finish(Database.BatchableContext BC){
		
		String hasErrors;
		String resultBody;
		if(errorTxt == ''){
			hasErrors = '';
			resultBody = ' has completed successfully.';
		} else {
			hasErrors = 'with Errors';
			resultBody = ' has complted with errors. \n\n' + errorTxt + '\n\n';
		}
		//query the parent and make a better body
		Campaign parentCampaign = [select id, name from Campaign where id=:parentCampaignId];
		
		Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
		
		mail.setToAddresses(new String[] {email});
		mail.setReplyTo(email);
		mail.setSenderDisplayName('Batch Processing of Campaigns');
		mail.setSubject('Campaign Segmentation Completed - ' + parentCampaign.name + ' ' + hasErrors);
		mail.setPlainTextBody('The segmentation of ' + parentCampaign.name + resultBody +' https://na1.salesforce.com/' + parentCampaign.Id);
		
		Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
	}
	
	public static testMethod void testBatch() {
		
		Integer segments = 2;
		Integer contacts = 200;
		//create a campaign
		Campaign parentCampaign = new Campaign(
			name='Parent for test',
			IsActive=true
		);
		
		insert parentCampaign;
		
		List<Contact> newContacts = new List<Contact>();
		
		
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
		
		List<Campaign> segmentCampaigns = new List<Campaign>();
		//create segments
		for (Integer segNum=0; segNum<segments;segNum++){
			Campaign thisCampaign = new Campaign(
				Name='Segment' + segNum,
				ParentId = parentCampaign.Id
			);
			segmentCampaigns.add(thisCampaign);
		}
		insert segmentCampaigns;
		List<Id> mySegmentIds = new List<Id>();
		for(Campaign myCamp : segmentCampaigns){
			mySegmentIds.add(myCamp.Id);
		}
		//set sizes
		List<Integer> sizes = new List<Integer>();
		sizes.add(100);
		sizes.add(100);
		
		List<Integer> members = new List<Integer>();
		members.add(0);
		members.add(0);

		Test.StartTest();
		batchSegmentCreator batch = new batchSegmentCreator();
		batch.query='select id,campaignId, leadId, contactid from campaignMember where CampaignId = \'' +  parentCampaign.Id + '\'';
		batch.email='admin@acme.com'; 
		batch.parentCampaignId = parentCampaign.Id; 
		batch.segmentCampaignIds = mySegmentIds; 
		batch.segmentSizes = sizes; 
		batch.membersAdded = members; 
		batch.keepOriginal = false;
		ID batchprocessid = Database.executeBatch(batch); 
		Test.StopTest();
		System.AssertEquals(database.countquery('SELECT count()' +' FROM CampaignMember WHERE campaignId=\'' + parentCampaign.Id + '\''), 0);
		System.AssertEquals(database.countquery('SELECT count()' +' FROM CampaignMember WHERE campaignId=\'' + mySegmentIds[0] + '\''), 100);
		System.AssertEquals(database.countquery('SELECT count()' +' FROM CampaignMember WHERE campaignId=\'' + mySegmentIds[1] + '\''), 100);
	}
	
}
