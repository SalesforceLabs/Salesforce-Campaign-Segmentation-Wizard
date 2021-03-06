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
public with sharing class memberAssignment {
	
	static Id campId;
	static List<Id> semgmentIds;
	static List<Integer> sizes;
	static List<Integer> members;
	static List<CampaignMember> newCampaignMembers;	
	static Boolean keep;
	
	public static boolean assignMembersNow(Id parentCampaignId, List<Id> segmentCampaignIds, List<Integer> segmentSizes, List<Integer> membersAdded, Boolean keepOriginal){
		campId = parentCampaignId;
		semgmentIds = segmentCampaignIds;
		sizes = segmentSizes;
		members = membersAdded;
		keep = keepOriginal;
		newCampaignMembers = new List<CampaignMember>();
		
		List<CampaignMember> oldMembers = [select id,campaignId, leadId, contactid from campaignMember where CampaignId = :campId];
		
		for(CampaignMember thisMember : oldMembers){
		 	assignMember(thisMember);		    
		}
		system.debug('******newCampaignMembers = '+newCampaignMembers);
		if(!newCampaignMembers.isEmpty()){
			try {
				insert newCampaignMembers;
				if(!keep){
					delete oldMembers;
				}
				return true;
			} catch (exception e){
				system.debug('******EXCEPTION = ' + e);
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