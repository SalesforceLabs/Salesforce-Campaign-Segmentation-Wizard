public with sharing class memberAssignment {
	
	static Id campId;
	static List<Id> semgmentIds;
	static List<Integer> sizes;
	static List<Integer> members;
	static List<CampaignMember> newCampaignMembers;	
	
	public static boolean assignMembersNow(Id parentCampaignId, List<Id> segmentCampaignIds, List<Integer> segmentSizes, List<Integer> membersAdded){
		campId = parentCampaignId;
		semgmentIds = segmentCampaignIds;
		sizes = segmentSizes;
		members = membersAdded;
		
		newCampaignMembers = new List<CampaignMember>();
		
		for(CampaignMember thisMember : [select id,campaignId, leadId, contactid from campaignMember where CampaignId = :campId]){
		 	assignMember(thisMember);		    
		}
		
		if(newCampaignMembers.size()!=0){
			try {
				insert newCampaignMembers;
				delete [select id,campaignId, leadId, contactid from campaignMember where CampaignId = :campId];
				return true;
			} catch (exception e){
				return false;
			}
		} else {
			return false;
		}
	}
			
	private static void assignMember(CampaignMember thisCampaignMember){
		Integer assignedList = Math.floor(semgmentIds.size() * Math.Random()).intValue();
		
		if((members[assignedList] < sizes[assignedList])){		    
			 newCampaignMembers.add(
			 	new CampaignMember(
					CampaignId = semgmentIds[assignedList],
					LeadId = thisCampaignMember.LeadId,
					ContactId = thisCampaignMember.ContactId		
			 	)
			 );
			 if(members[assignedList] < sizes[assignedList]){
			 	members[assignedList]++;
			 }
		} else {
			assignMember(thisCampaignMember);
		}
	}
		
		
	
	    
	    
	
}