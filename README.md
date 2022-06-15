# Apex Windfarm
Leads are the wind power of all organisations.
Accounts, Contacts and Opportunities are the energy that feeds them and makes all the things happen.

```
 __        __                 __        __                 __        __
 \ \      / /                 \ \      / /                 \ \      / /
  \ \    / /                   \ \    / /                   \ \    / /
   \ \  / /                     \ \  / /                     \ \  / /
    \ \/ /                       \ \/ /                       \ \/ / 
     (  )                         (  )                         (  )  
    / /\ \                       / /\ \                       / /\ \ 
   / /  \ \                     / /  \ \                     / /  \ \
  / /|  |\ \                   / /|  |\ \                   / /|  |\ \
 /_/ |  | \_\                 /_/ |  | \_\                 /_/ |  | \_\
    _|  |_                       _|  |_                       _|  |_
   |      |                     |      |                     |      |
   | APEX |                     | WIND |                     | FARM |
   |_    _|                     |_    _|                     |_    _|
     |  |                         |  |                         |  |
_____|__|_____               _____|__|_____               _____|__|_____ 
vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
```
- [Apex Windfarm](#apex-windfarm)
  * [Introduction](#introduction)
  * [Native Lead conversion](#native-lead-conversion)
    + [Apex `Database.LeadConvert` class](#apex-databaseleadconvert-class)
    + [Apex `Database.convertLead` static method](#apex-databaseconvertlead-static-method)
  * [What's wrong with the native Lead conversion?](#whats-wrong-with-the-native-lead-conversion)

## Introduction
Unfortunatelly, Apex internal codebase doesn't tackle this conversion the best way. We'll briefly discuss here how `Database.LeadConvert` seems to hurt quite a few best practices and principles and how poor the decision to delegate all the validations to `Database.convertLead()` is, as it requires all the burden of a database call to realise there could be a mistaken setup.

Windfarm is a way to both help build the conversion setup and to check for errors before hitting the database, consequently keeping your code lightweight.  

**Deploy this to your Salesforce Org:**

[![Deploy to Salesforce](https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png)](https://githubsfdeploy.herokuapp.com/?owner=berardo&repo=apex-windfarm&ref=master)

## Native Lead conversion

First things first, let's cover what a Lead conversion actually is.
From a marketing perspective, a Lead is a person who shows interest in a company's product or a service, which makes them a potential customer.
Sometimes, the same person can show interest on another product or service and it really depends on how far apart the two interests are in the company to determine if this is going to be treated as a duplicate or a genuine new chance of becoming an opportunity.

### Apex `Database.LeadConvert` class
I don't intend to get into the rabbit hole of duplicate leads, genuine leads, leads vs opportunities. However, what's important for a Salesforce Developer is the fact that lead conversions are necessarily made of the following **three** things:

1. The Lead
    - I know this is really obvious, but yeah it's my chance to say "Lead", not "Lead Id"
    - The native `LeadConvert` class only works with Ids though:
    ```java
    Lead l = new Lead(LastName = 'Fry', Company = 'Fry And Sons');
    insert l;

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    ```

1. The new lead status
    - This is again another tricky part. `LeadStatus` is an entirely separate Salesforce object. The code snippet below is a SOQL query to list all Lead Statuses on a brand new Developer edition scratch org:
    ```bash
    force:data:soql:query --query "SELECT Id, ApiName, IsConverted, IsDefault FROM LeadStatus"
    Querying Data... done
    ID                  APINAME                 ISCONVERTED  ISDEFAULT
    ──────────────────  ──────────────────────  ───────────  ─────────
    01J0p00000CHWBaEAP  Closed - Converted      true         false
    01J0p00000CHWBbEAP  Closed - Not Converted  false        false
    01J0p00000CHWBdEAP  Working - Contacted     false        false
    01J0p00000CHWBcEAP  Open - Not Contacted    false        true
    Total number of records retrieved: 4.
    ```
    This can be a bit confusing as Lead Status is also a picklist field on the Lead object (`Lead.Status`), which means it's a field that only accepts simple texts, however, any chosen text must not only be an existing `ApiName` on the `LeadStatus` object, but also from a record that has `IsConverted` set to `true`, otherwise a `DmlException` with `StatusCode.INVALID_STATUS` would be thrown.
    The code snippet below shows a safe way to find a converted status, however you could have just hard-coded any converted status string in case you knew it upfront.
    ```java
    // ... follow up on previous code snippet
    LeadStatus converted = [
      SELECT ApiName
      FROM LeadStatus
      WHERE IsConverted = TRUE
      LIMIT 1
    ];
    lc.setConvertedStatus(converted.ApiName);
    ```
    Before we move ahead to the third and last configuration step, you could think, what if the `LeadConvert` accepted a `Lead` instance as we claimed on the first step? This could be something like:
    ```java
    // ... this code doesn't work, it's just your imagination going wild
    Lead l = new Lead(LastName = 'Fry', Company = 'Fry And Sons');
    insert l;

    LeadStatus converted = [
      SELECT ApiName
      FROM LeadStatus
      WHERE IsConverted = TRUE
      LIMIT 1
    ];
    l.Status = converted.ApiName;

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLead(l);
    ```
    You can always disagree, but this design looks slightly more elegant and cohesive to me as `Status` clearly belongs to the `Lead` not to the conversion itself.
    If you are still not convinced, may I ask you what `lc.setConvertedStatus(converted.ApiName)` really does? Does it set anything, anywhere?
    - The answer is NO. It does NOTHING, at least until the static method `Database.convertLead` is called (we'll get back to this 'beatiful' guy later on).
    - Changing the Lead instance in memory could be enough to trigger the conversion process with a simple `update` command, but this is not true. If you set the lead status as above and save it, only the lead record will be changed, no conversion process will be triggered, consequently, no new account, contact or opportunity is created and finally no map lead fields process takes place.
  1. The outcome alternatives (optional)
      - From the previous item, if nothing else is provided here, the outcome will be:
        1. A new business `Account` whose `Name` is the same as `Lead.Company`
        1. A new `Contact` whose `FirstName` and `LastName` are the same as the lead's counterpart. Also `AccountId` is the `Id` of the just created business account.
        1. An `Opportunity` whose `Name` is also the same as `Lead.Company`
        - All **custom fields** of the three records above are populated according to what's defined on the **| Setup &raquo; Object Manager &raquo; Lead &raquo; Fields and Relationships &raquo; Map Lead Fields |** page
        - Stop, please, stop! Can't you see what's wrong here? The outcome depends on the saved state of the lead record passed down on `setLeadId()`. So why does the `Status` require a separate method on `LeadConvert`?
      - Ok, I think you got my point, so let's take a look at what we can do to get alternative outcomes:
        1. **`setAccountId(Id)`**:
            - When `AccountId` is given (`leadConvert.setAccountId(acctId)`), no new `Account` record is created and custom fields can be populated as per Map Lead Fields but only the fields that are **still null** on the given account.
            - Look, it's not an Account record, but the Account Id. Actually, there's no big deal here as no other information on the account record is used on any circunstance, but look what happens to others below.
        1. **`setContactId(Id)`**:
            - Oh, another Id. When `ContactId` is given, `AccountId` becomes mandatory and the given contact must belong to the given account (`Contact.AccountId == AccountId`), consequently neither account nor contact records are created, and fields that are still null on both records can be populated as per Map Lead Fields
            -  I wonder if this internal query could've been skipped if the object (that you probably already have in memory) was passed over and caught on a simple equality comparison that it's not parented by the account.
            - Another question that comes up is why is `AccountId` mandatory when `ContactId` is defined? The saved contact record is always checked on whether it belongs to the given account, so wouldn't it be simpler if it took the account Id from the contact and `setAccountId` was not allowed rather than mandatory?
        1. **`setOpportunityId(Id)`**:
            - When `OpportunityId` is given, `AccountId` becomes mandatory and the given opportunity must belong to the given account (`Opportunity.AccountId == AccountId`), consequently neither account nor opportunity records are created
            - Another Id. Ok, at least it's consistent. The query-skipping idea for contacts also apply here.
            - Different from the contact's behaviour, when `OpportunityId` and `AccountId` are defined, the targeted opportunity **can** have its own `AccountId` field as null, which means that the given opportunity doesn't need to be parented by the given account, it just cannot be parented by another account.
        1. **`setDoNotCreateOpportunity(Boolean)`**:
            - Like you could do on the Lead conversion Salesforce UI modal, a flag can be set up to prevent the creation of an `Opportunity`. This is defined by `setDoNotCreateOpportunity(true)` as per the code below:
              ```java
              Database.LeadConvert lc = new Database.LeadConvert();
              lc.setDoNotCreateOpportunity(true);
              // With the line above, the following lines are not accepted
              // DmlException -> INVALID_FIELD
              lc.setOpportunityId(opportunityId);
              lc.setOpportunityName('New Opportunity Name');
              ```
        1. **`setOpportunityName(String)`**:
            - As mentioned before, custom fields can be mapped from `Lead` to `Account`, `Contact` and `Opportunity`. You also know standard mapping like `Lead` `FirstName` and `LastName` to their `Contact` counterparts and `Lead` `Company` to `Account` `Name` as well as `Opportunity` `Name`.
            - That's exactly the very last item of this list that can be overwritten by the method `setOpportunityName('New Oppty Name')`, but be mindful it cannot come along with `setOpportunityId(Id)` as the former is to define the new record name, while the latter is to define an existing `Opportunity` record. See this example:
              ```java
              Database.LeadConvert lc = new Database.LeadConvert();
              lc.setOpportunityName('New Opportunity Name');
              // With the line above, the following line are not accepted
              // DmlException -> INVALID_FIELD
              lc.setOpportunityId(opportunityId);
              ```
        1. **`setOverwriteLeadSource(Boolean)`**:
            - `LeadSource` is a common field on `Lead`, `Account`, `Contact` and `Opportunity`, although on account it's called `AccountSource`. It's a standard global value set (`StandardValueSet` on Metadata API) that doesn't appear on **| Setup &raquo; Pick List Value Sets** | page but can be tracked on source code and also be updated on any of the mentioned objects
            - When a Lead is converted to brand new records on the other side, all LeadSource fields are populated with what's in the Lead. When it's converted to existing records on the other hand, the mapping rule of thumb of only null fields are populated is by default observed
            - Unless ... yep, you got it, unless `setOverwiteLeadSource(true)` is set
            - However, I left the "best" slice to the end. It only affects existing Contacts. Yeah, you got it right. Using this super weird configuration, the targeted `Contact` only will have whatever existing value in there replaced by the `Lead`'s `LeadSource`. ¯\\\_(ツ)_/¯
        1. **`setOwnerId(Id)`**:
            - I know ... another Id. (╯°□°)╯︵ ┻━┻
            - This can be used to define the owner of the newly created records, otherwise the current user is assigned
        1. **`setSendNotificationEmail(Boolean)`**:
            - In my humble opinion, this the only configuration that belongs to the conversion process, not any particular map. It's also super intuitive, it's used to send an email to the new records owner once the conversion is completed.
### Apex `Database.convertLead` static method

In order to run a lead conversion, you work with an instance of `Database.LeadConvert` then pass them over to `Database.convertLead` like the code below:
```java
Lead l = new Lead(LastName = 'Fry', Company = 'Fry And Sons');
insert l;

Database.LeadConvert lc = new Database.LeadConvert();
lc.setLeadId(l.Id);
lc.setConvertedStatus('Closed - Converted');

Database.LeadConvertResult lcr = Database.convertLead(lc);

System.assert(lcr.isSuccess(), 'Success conversion is expected');
```
It returns an instance of `Database.LeadConvertResult` that can be used to immediatelly get the created records' Ids as well as an overall `isSuccess()` outcome and a list of errors if any. This method also accepts a list of `LeadConvert`, and returns a list of `LeadConvertResult`.

## What's wrong with the native Lead conversion?

The `LeadConvert` class starts with absolutely non-intuitive ways to deal with the necessary data to plan ahead the conversion.
It all starts at the constructor, right? What does it require? Nothing. Ok, but it creates a `LeadConvert` record that serves no purpose whatsoever.
What would you do with a conversion plan that doesn't know what Lead to convert?

The second mistake is the preference for Ids over objects. Looks like their creators didn't know much about OOP or hated enough to run away from it. Basicaly, I covered this topic already when I mentioned that if a Lead was accepted, it could bring over not only its Id but also its `Status`, so no extra method would be called.
I also covered it when talked about `Contact` and `Opportunity` Ids, as if object instances were given they could bring over their `AccountId` or `Account.Id`. Missing `AccountId` errors would happen.
Passing objects, errors about providing `Opportunity` Name and Id (they are mutually exclusive) could be totally avoided. For example, when `Opportunity.Id` is given it's taken, otherwise the `Name`, if populated on the instance, could be used on the new record.

Finally, the worst part. Nothing happens until `Database.converLead()` is run. Again, this creates a hard dependency on the database to simply observe that the configuration was wrong and the reason wasn't even on the saved data but on things set up previously.

Have a look at the results of run of [DatabaseConvertTest class](force-app/main/default/classes/DatabaseConvertTest.cls) to see how it performs. Important to highlight this is a brand new scratch org, so there's absolutely no trigger or flow on top of that. It's time consumed with pure persistence operations.

```sql
=== Test Summary
NAME                 VALUE                        
───────────────────  ─────────────────────────────
Outcome              Passed                       
Tests Ran            17                           
Pass Rate            100%                         
Fail Rate            0%                           
Skip Rate            0%                           
Test Run Id          7070p000014fsHM              
Test Execution Time  9015 ms                      
Org Id               00D0p0000001ZHrEAM           
Username             test-momaqki9oxgk@example.com


=== Test Results
TEST NAME                                                                     OUTCOME  MESSAGE  RUNTIME (MS)
────────────────────────────────────────────────────────────────────────────  ───────  ───────  ────────────
DatabaseConvertTest.testConvertLead                                           Pass              1834        
DatabaseConvertTest.testConvertLeadToAll                                      Pass              677         
DatabaseConvertTest.testConvertLeadToAllOverwriteLeadSource                   Pass              694         
DatabaseConvertTest.testConvertLeadToExistingAccount                          Pass              741         
DatabaseConvertTest.testConvertLeadToLinkedAccountAndContact                  Pass              536         
DatabaseConvertTest.testConvertLeadToLinkedAccountAndOpportunity              Pass              679         
DatabaseConvertTest.testConvertLeadToLinkedAccountAndOpportunityAndOpptyName  Pass              188         
DatabaseConvertTest.testConvertLeadToLinkedAccountAndOpportunityWithNoFlag    Pass              189         
DatabaseConvertTest.testConvertLeadToNotLinkedAccountAndContact               Pass              280         
DatabaseConvertTest.testConvertLeadToNotLinkedAccountAndOpportunity           Pass              597         
DatabaseConvertTest.testConvertLeadToNotMatchingAccountAndContact             Pass              277         
DatabaseConvertTest.testConvertLeadToNotMatchingAccountAndOpportunity         Pass              249         
DatabaseConvertTest.testConvertLeadToOnlyContact                              Pass              174         
DatabaseConvertTest.testConvertLeadToOnlyOpportunity                          Pass              161         
DatabaseConvertTest.testConvertLeadWithOpportunityName                        Pass              679         
DatabaseConvertTest.testConvertLeadWithoutOpportunity                         Pass              937         
DatabaseConvertTest.testsetLeadStatusToConverted                              Pass              123         
```

Almost 10s to run 17 test cases. Particularly the tests `testConvertLead` that is the simplest possible, consequently creates all of the three new records, and `testConvertLeadWithoutOpportunity` that does the same except creating new opportunities, are nearly 2s and 1s respectively.
If the only intention is to check whether the settings are valid to perform the conversion, creating the actual records crosses the border of unit tests and becomes an integration, as test cases could also fail due to not closely related validation rules, trigger further checks, flows conditions not met, and so on.