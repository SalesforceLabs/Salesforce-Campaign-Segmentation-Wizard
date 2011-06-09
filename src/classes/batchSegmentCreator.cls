global class batchSegmentCreator implements Database.Batchable<SObject>{
	global String query;
	global String email;
	global Id parentCampaignId;
	global List<Id> segmentCampaignIds;
	global List<Integer> segmentSizes;
	global List<Integer> membersAdded;
	global Boolean success;
	
	global database.querylocator start(Database.BatchableContext BC){
	            return Database.getQueryLocator(query);}
	
	global void execute(Database.BatchableContext BC, List<sObject> scope){
		boolean thisBatchSuccess = memberAssignment.assignMembersNow(parentCampaignId,segmentCampaignIds,segmentSizes,membersAdded);
	    if(!thisBatchSuccess){
	    	success = false;
	    }
	}
	global void finish(Database.BatchableContext BC){
		String resultHeader;
		String resultBody;
		if(success){
			resultHeader = 'Success';
			resultBody = ' has completed successfully.';
		} else {
			resultHeader = 'Failure';
			resultBody = ' has failed. Please try again.';
		}
		//query the parent and make a better body
		Campaign parentCampaign = [select id, name from Campaign where id=:parentCampaignId];
		
		Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
		
		mail.setToAddresses(new String[] {email});
		mail.setReplyTo('steve@gokubi.com');
		mail.setSenderDisplayName('Batch Processing of Campaigns');
		mail.setSubject(resultHeader + ': Campaign Segmentation Completed - ' + parentCampaign.name);
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
		ID batchprocessid = Database.executeBatch(batch); 
		Test.StopTest();
		System.AssertEquals(database.countquery('SELECT count()' +' FROM CampaignMember WHERE campaignId=\'' + parentCampaign.Id + '\''), 0);
		System.AssertEquals(database.countquery('SELECT count()' +' FROM CampaignMember WHERE campaignId=\'' + mySegmentIds[0] + '\''), 100);
		System.AssertEquals(database.countquery('SELECT count()' +' FROM CampaignMember WHERE campaignId=\'' + mySegmentIds[1] + '\''), 100);
	}
	
}