/**
 * Main Lead conversion test class.
 * No Apex code is tested, this is just to check the expected database behaviour that dictates the Windfarm.
 * 
 * Examples derived from `LeadConvert` class docs
 * @see https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_dml_convertLead.htm
 */
@isTest
public class DatabaseConvertTest {
  @isTest
  static void testsetLeadStatusToConverted() {
    Lead l = new Lead(LastName = 'Fry', Company = 'Fry And Sons');
    insert l;

    l.Status = getFirstConvertedStatus();

    Database.SaveResult sres = Database.update(l);
    l = [ SELECT Id, IsConverted, ConvertedDate FROM Lead WHERE Id = :l.Id ];

    System.assert(sres.isSuccess(), 'Success update is expected');

    List<Account> accts = getSavedAccounts();
    List<Contact> conts = getSavedContacts();
    List<Opportunity> oppties = getSavedOpportunities();

    System.assert(!l.IsConverted, 'Lead should not be flagged as converted');
    System.assertEquals(null, l.ConvertedDate, 'Converted date should be null');
    System.assert(accts.isEmpty(), 'No account should be created');
    System.assert(conts.isEmpty(), 'No contact should be created');
    System.assert(oppties.isEmpty(), 'No opportunity should be created');
  }
  /**
   * Nothing other than LeadId is provided, therefore an Account, a Contact and an Opportunity
   * will be created
   */
  @isTest
  static void testConvertLead() {
    Lead l = new Lead(LastName = 'Fry', FirstName = 'Deep', Company = 'Fry And Sons');
    insert l;

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    lc.setConvertedStatus(getFirstConvertedStatus());

    Database.LeadConvertResult lcr = Database.convertLead(lc);
    
    System.assert(lcr.isSuccess(), 'Success conversion is expected');
    
    List<Account> accts = getSavedAccounts();
    
    l = [ SELECT Id, IsConverted, ConvertedDate, Company FROM Lead WHERE Id = :l.Id ];
    System.assert(l.IsConverted, 'Lead should be flagged as converted');
    System.assertNotEquals(null, l.ConvertedDate, 'Converted date should not be null');
    System.assertEquals(1, accts.size(), 'An account should be created');
    System.assertEquals(1, accts.get(0).Contacts.size(), 'A contact should be created');
    System.assertEquals(1, accts.get(0).Opportunities.size(), 'An opportunity should be created');
    Account acct = accts.get(0);
    System.assertEquals('Fry And Sons', acct.Name, 'Account name should be Lead.Company');
    System.assertEquals('Fry', acct.Contacts.get(0).LastName, 'Contact last name should be Lead.LastName');
    System.assertEquals('Deep', acct.Contacts.get(0).FirstName, 'Contact first name should be Lead.FirstName');
    System.assertEquals('Fry And Sons', acct.Opportunities.get(0).Name, 'Opportunity name should be Lead.Company');
    System.assertEquals(acct.Id, acct.Contacts.get(0).AccountId, 'Contact AccountId should be Account.Id');
    System.assertEquals(acct.Id, acct.Opportunities.get(0).AccountId, 'Opportunity AccountId should be Account.Id');
    System.assertEquals(l.Company, acct.Opportunities.get(0).Name, 'Opportunity name should be Lead.Company');
  }

  /**
   * An existing AccountId is provided, therefore only a Contact and an Opportunity will be created
   */
  @isTest
  static void testConvertLeadToExistingAccount() {
    Account acct = new Account(Name = 'Fry, Sons And Friends');
    insert acct;

    Lead l = new Lead(LastName = 'Fry', Company = 'Fry And Sons');
    insert l;

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    lc.setConvertedStatus(getFirstConvertedStatus());
    lc.setAccountId(acct.Id);

    Database.LeadConvertResult lcr = Database.convertLead(lc);

    System.assert(lcr.isSuccess(), 'Success conversion is expected');

    List<Account> accts = getSavedAccounts();

    System.assertEquals(1, accts.size(), 'An account should be created');
    System.assertEquals(1, accts.get(0).Contacts.size(), 'A contact should be created');
    System.assertEquals(1, accts.get(0).Opportunities.size(), 'An opportunity should be created');
    System.assertEquals('Fry, Sons And Friends', accts.get(0).Name, 'Account name should not be overwritten');
    System.assertEquals('Fry', accts.get(0).Contacts.get(0).LastName, 'Contact last name should be Lead.LastName');
    System.assertEquals('Fry And Sons', accts.get(0).Opportunities.get(0).Name, 'Opportunity name should be Lead.Company');
  }

  /**
   * Existing AccountId and ContactId are provided, therefore only a new Opportunity will be created
   */
  @isTest
  static void testConvertLeadToLinkedAccountAndContact() {
    Account acct = new Account(Name = 'Fry, Sons And Friends');
    insert acct;

    Contact cont = new Contact(LastName = 'Deep Fry', AccountId = acct.Id);
    insert cont;

    Lead l = new Lead(LastName = 'Fry', Company = 'Fry And Sons');
    insert l;

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    lc.setConvertedStatus(getFirstConvertedStatus());
    lc.setAccountId(acct.Id);
    lc.setContactId(cont.Id);

    Database.LeadConvertResult lcr = Database.convertLead(lc);

    System.assert(lcr.isSuccess(), 'Success conversion is expected');

    List<Account> accts = getSavedAccounts();
    List<Contact> conts = getSavedContacts();

    System.assertEquals(1, accts.size(), 'No new account should be created');
    System.assertEquals(1, conts.size(), 'No new contact should be created');
    System.assertEquals(1, accts.get(0).Opportunities.size(), 'An opportunity should be created');
    System.assertEquals(accts.get(0).Contacts.get(0).Id, conts.get(0).Id, 'No association change is expected');
    System.assertEquals('Fry, Sons And Friends', accts.get(0).Name, 'Account name should not be overwritten');
    System.assertEquals('Deep Fry', conts.get(0).LastName, 'Contact last name should not be overwritten');
    System.assertEquals('Fry And Sons', accts.get(0).Opportunities.get(0).Name, 'Opportunity name should be Lead.Company');
  }

  /**
   * Existing AccountId and ContactId are provided, however, the contact's account id is null,
   * therefore an exception will be thrown as the contact must be parented by the account
   */
  @isTest
  static void testConvertLeadToNotLinkedAccountAndContact() {
    Account acct = new Account(Name = 'Fry, Sons And Friends');
    insert acct;

    Contact cont = new Contact(LastName = 'Deep Fry');
    insert cont;

    Lead l = new Lead(LastName = 'Fry', Company = 'Fry And Sons');
    insert l;

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    lc.setConvertedStatus(getFirstConvertedStatus());
    lc.setAccountId(acct.Id);
    lc.setContactId(cont.Id);

    try {
      Database.LeadConvertResult lcr = Database.convertLead(lc);
      System.assert(false, 'This line should not be reached ' + lcr);
    } catch (DmlException ex) {
      System.assertEquals(1, ex.getNumDml(), 'One DML error should be raised');
      System.assertEquals(StatusCode.INVALID_ID_FIELD, ex.getDmlType(0), 'Invalid field error should be raised');
      System.assert(ex.getDmlFieldNames(0).isEmpty(), 'No specific field could be reported against');
    }
  }

  /**
   * Existing AccountId and ContactId are provided, however, the contact's account id is not
   * the given account, therefore an exception will be thrown as the contact must be parented
   * by the account
   */
  @isTest
  static void testConvertLeadToNotMatchingAccountAndContact() {
    Account acct1 = new Account(Name = 'Fry, Sons And Friends');
    Account acct2 = new Account(Name = 'Baked Not Fried');
    insert new List<Account> { acct1, acct2 };

    Contact cont = new Contact(LastName = 'Deep Fry', AccountId = acct1.Id);
    insert cont;

    Lead l = new Lead(LastName = 'Fry', Company = 'Fry And Sons');
    insert l;

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    lc.setConvertedStatus(getFirstConvertedStatus());
    lc.setAccountId(acct2.Id);
    lc.setContactId(cont.Id);

    try {
      Database.LeadConvertResult lcr = Database.convertLead(lc);
      System.assert(false, 'This line should not be reached ' + lcr);
    } catch (DmlException ex) {
      System.assertEquals(1, ex.getNumDml(), 'One DML error should be raised');
      System.assertEquals(StatusCode.INVALID_ID_FIELD, ex.getDmlType(0), 'Invalid field error should be raised');
      System.assert(ex.getDmlFieldNames(0).isEmpty(), 'No specific field could be reported against');
    }
  }

  /**
   * A ContactId is provided, therefore an exception will be thrown as the AccountId
   * is now mandatory
   */
  @isTest
  static void testConvertLeadToOnlyContact() {
    Account acct = new Account(Name = 'Fry, Sons And Friends');
    insert acct;

    Contact cont = new Contact(LastName = 'Deep Fry', AccountId = acct.Id);
    insert cont;

    Lead l = new Lead(LastName = 'Fry', Company = 'Fry And Sons');
    insert l;

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    lc.setConvertedStatus(getFirstConvertedStatus());
    lc.setContactId(cont.Id);

    try {
      Database.LeadConvertResult lcr = Database.convertLead(lc);
      System.assert(false, 'This line should not be reached ' + lcr);
    } catch (DmlException ex) {
      System.assertEquals(1, ex.getNumDml(), 'One DML error should be raised');
      System.assertEquals(StatusCode.REQUIRED_FIELD_MISSING, ex.getDmlType(0), 'Invalid field error should be raised');
      System.assertEquals(1, ex.getDmlFieldNames(0).size(), 'One specific field could be reported against');
      System.assertEquals('Id', ex.getDmlFieldNames(0).get(0), 'The reported field should be the generic `Id`');
      System.assert(ex.getMessage().contains('accountId must be specified if contactId is not null'), 'Not the expected message was returned');
    }
  }

  /**
   * Existing AccountId and OpportunityId are provided, therefore only a new Contact will be created
   */
  @isTest
  static void testConvertLeadToLinkedAccountAndOpportunity() {
    Account acct = new Account(Name = 'Fry, Sons And Friends');
    insert acct;

    Opportunity oppty = new Opportunity(
      Name = 'Deep Fry',
      AccountId = acct.Id,
      CloseDate = Date.today(),
      StageName = 'Prospecting'
    );
    insert oppty;

    Lead l = new Lead(LastName = 'Fry', Company = 'Fry And Sons');
    insert l;

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    lc.setConvertedStatus(getFirstConvertedStatus());
    lc.setAccountId(acct.Id);
    lc.setOpportunityId(oppty.Id);

    Database.LeadConvertResult lcr = Database.convertLead(lc);

    System.assert(lcr.isSuccess(), 'Success conversion is expected');

    List<Account> accts = getSavedAccounts();
    List<Opportunity> oppties = getSavedOpportunities();

    System.assertEquals(1, accts.size(), 'No new account should be created');
    System.assertEquals(1, oppties.size(), 'No new opportunity should be created');
    System.assertEquals(1, accts.get(0).Contacts.size(), 'A contact should be created');
    System.assertEquals(accts.get(0).Opportunities.get(0).Id, oppties.get(0).Id, 'No association change is expected');
    System.assertEquals('Fry, Sons And Friends', accts.get(0).Name, 'Account name should not be overwritten');
    System.assertEquals('Deep Fry', oppties.get(0).Name, 'Opportunity name should not be overwritten');
    System.assertEquals('Fry', accts.get(0).Contacts.get(0).LastName, 'Contact name should be Lead.LastName');
  }

  /**
   * Existing AccountId and OpportunityId are provided, and the opportunity's AccountId is null,
   * which is acceptable, therefore only a new Contact will be created
   */
  @isTest
  static void testConvertLeadToNotLinkedAccountAndOpportunity() {
    Account acct = new Account(Name = 'Fry, Sons And Friends');
    insert acct;

    Opportunity oppty = new Opportunity(
      Name = 'Deep Fry',
      CloseDate = Date.today(),
      StageName = 'Prospecting'
    );
    insert oppty;

    Lead l = new Lead(LastName = 'Fry', Company = 'Fry And Sons');
    insert l;

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    lc.setConvertedStatus(getFirstConvertedStatus());
    lc.setAccountId(acct.Id);
    lc.setOpportunityId(oppty.Id);

    Database.LeadConvertResult lcr = Database.convertLead(lc);

    System.assert(lcr.isSuccess(), 'Success conversion is expected');

    List<Account> accts = getSavedAccounts();
    List<Opportunity> oppties = getSavedOpportunities();

    System.assertEquals(1, accts.size(), 'No new account should be created');
    System.assertEquals(1, oppties.size(), 'No new opportunity should be created');
    System.assertEquals(1, accts.get(0).Contacts.size(), 'A contact should be created');
    System.assert(accts.get(0).Opportunities.isEmpty(), 'No association change should be made');
    System.assertEquals('Fry, Sons And Friends', accts.get(0).Name, 'Account name should not be overwritten');
    System.assertEquals('Deep Fry', oppties.get(0).Name, 'Opportunity name should not be overwritten');
    System.assertEquals(null, oppties.get(0).AccountId, 'Opportunity AccountId should not be set');
    System.assertEquals('Fry', accts.get(0).Contacts.get(0).LastName, 'Contact name should be Lead.LastName');
  }

  /**
   * Existing AccountId and OpportunityId are provided, but the opportunity's AccountId is not
   * equals to the given AccountId, therefore an exception will be thrown as the opportunity must
   * be parented by the account
   */
  @isTest
  static void testConvertLeadToNotMatchingAccountAndOpportunity() {
    Account acct1 = new Account(Name = 'Fry, Sons And Friends');
    Account acct2 = new Account(Name = 'Baked Not Fried');
    insert new List<Account> { acct1, acct2 };

    Opportunity oppty = new Opportunity(
      Name = 'Deep Fry',
      CloseDate = Date.today(),
      StageName = 'Prospecting',
      AccountId = acct1.Id
    );
    insert oppty;

    Lead l = new Lead(LastName = 'Fry', Company = 'Fry And Sons');
    insert l;

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    lc.setConvertedStatus(getFirstConvertedStatus());
    lc.setAccountId(acct2.Id);
    lc.setOpportunityId(oppty.Id);

    try {
      Database.LeadConvertResult lcr = Database.convertLead(lc);
      System.assert(false, 'This line should not be reached ' + lcr);
    } catch (DmlException ex) {
      System.assertEquals(1, ex.getNumDml(), 'One DML error should be raised');
      System.assertEquals(StatusCode.INVALID_ID_FIELD, ex.getDmlType(0), 'Invalid field error should be raised');
      System.assert(ex.getDmlFieldNames(0).isEmpty(), 'No specific field could be reported against');
    }
  }

  /**
   * An OpportunityId is provided, therefore an exception will be thrown as the AccountId
   * is now mandatory
   */
  @isTest
  static void testConvertLeadToOnlyOpportunity() {
    Account acct = new Account(Name = 'Fry, Sons And Friends');
    insert acct;

    Opportunity oppty = new Opportunity(
      Name = 'Deep Fry',
      CloseDate = Date.today(),
      StageName = 'Prospecting',
      AccountId = acct.Id
    );
    insert oppty;

    Lead l = new Lead(LastName = 'Fry', Company = 'Fry And Sons');
    insert l;

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    lc.setConvertedStatus(getFirstConvertedStatus());
    lc.setOpportunityId(oppty.Id);

    try {
      Database.LeadConvertResult lcr = Database.convertLead(lc);
      System.assert(false, 'This line should not be reached ' + lcr);
    } catch (DmlException ex) {
      System.assertEquals(1, ex.getNumDml(), 'One DML error should be raised');
      System.assertEquals(StatusCode.INVALID_FIELD, ex.getDmlType(0), 'Invalid field error should be raised');
      System.assertEquals(1, ex.getDmlFieldNames(0).size(), 'One specific field could be reported against');
      System.assertEquals('Id', ex.getDmlFieldNames(0).get(0), 'The reported field should be the generic `Id`');
      System.assert(ex.getMessage().contains('Specify an accountId if opportunityId is not null'), 'Not the expected message was returned');
    }
  }

    /**
   * Same as the test above, however, there's an explicity flag to do not create an Opportunity
   */
  @isTest
  static void testConvertLeadWithoutOpportunity() {
    Lead l = new Lead(LastName = 'Fry', Company = 'Fry And Sons');
    insert l;

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    lc.setConvertedStatus(getFirstConvertedStatus());
    lc.setDoNotCreateOpportunity(true);

    Database.LeadConvertResult lcr = Database.convertLead(lc);

    System.assert(lcr.isSuccess(), 'Success conversion is expected');

    List<Account> accts = getSavedAccounts();

    l = [ SELECT Id, IsConverted, ConvertedDate FROM Lead WHERE Id = :l.Id ];
    System.assert(l.IsConverted, 'Lead should be flagged as converted');
    System.assertNotEquals(null, l.ConvertedDate, 'Converted date should not be null');
    System.assertEquals(1, accts.size(), 'An account should be created');
    System.assertEquals(1, accts.get(0).Contacts.size(), 'A contact should be created');
    System.assert(accts.get(0).Opportunities.isEmpty(), 'No opportunity should be created');
    Account acct = accts.get(0);
    System.assertEquals('Fry And Sons', acct.Name, 'Account name should be Lead.Company');
    System.assertEquals('Fry', acct.Contacts.get(0).LastName, 'Contact last name should be Lead.LastName');
    System.assertEquals(acct.Id, acct.Contacts.get(0).AccountId, 'Contact AccountId should be Account.Id');
  }

  /**
   * Same as the test above, however, there's an explicity flag to do not create an Opportunity
   */
  @isTest
  static void testConvertLeadWithOpportunityName() {
    Lead l = new Lead(LastName = 'Fry', FirstName = 'Deep', Company = 'Fry And Sons');
    insert l;

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    lc.setConvertedStatus(getFirstConvertedStatus());
    lc.setOpportunityName('Named on the Fly');

    Database.LeadConvertResult lcr = Database.convertLead(lc);

    System.assert(lcr.isSuccess(), 'Success conversion is expected');

    List<Account> accts = getSavedAccounts();

    l = [ SELECT Id, IsConverted, ConvertedDate FROM Lead WHERE Id = :l.Id ];
    System.assert(l.IsConverted, 'Lead should be flagged as converted');
    System.assertNotEquals(null, l.ConvertedDate, 'Converted date should not be null');
    System.assertEquals(1, accts.size(), 'An account should be created');
    System.assertEquals(1, accts.get(0).Contacts.size(), 'A contact should be created');
    Account acct = accts.get(0);
    System.assertEquals('Fry And Sons', acct.Name, 'Account name should be Lead.Company');
    System.assertEquals('Fry', acct.Contacts.get(0).LastName, 'Contact last name should be Lead.LastName');
    System.assertEquals('Deep', acct.Contacts.get(0).FirstName, 'Contact last name should be Lead.LastName');
    System.assertEquals(acct.Id, acct.Contacts.get(0).AccountId, 'Contact AccountId should be Account.Id');
    System.assertEquals('Named on the Fly', acct.Opportunities.get(0).Name, 'Opportunity name should be Account.Id');
  }

  /**
   * Existing AccountId and OpportunityId are provided, but the DoNotCreateOpportunity flag
   * is true, this is an inconsitent state, therefore an exception will be thrown
   */
  @isTest
  static void testConvertLeadToLinkedAccountAndOpportunityWithNoFlag() {
    Account acct = new Account(Name = 'Fry, Sons And Friends');
    insert acct;

    Opportunity oppty = new Opportunity(
      Name = 'Deep Fry',
      AccountId = acct.Id,
      CloseDate = Date.today(),
      StageName = 'Prospecting'
    );
    insert oppty;

    Lead l = new Lead(LastName = 'Fry', Company = 'Fry And Sons');
    insert l;

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    lc.setConvertedStatus(getFirstConvertedStatus());
    lc.setAccountId(acct.Id);
    lc.setOpportunityId(oppty.Id);
    lc.setDoNotCreateOpportunity(true);

    try {
      Database.LeadConvertResult lcr = Database.convertLead(lc);
      System.assert(false, 'This line should not be reached ' + lcr);
    } catch (DmlException ex) {
      System.assertEquals(1, ex.getNumDml(), 'One DML error should be raised');
      System.assertEquals(StatusCode.INVALID_FIELD, ex.getDmlType(0), 'Invalid field error should be raised');
      System.assertEquals(1, ex.getDmlFieldNames(0).size(), 'One specific field could be reported against');
      System.assertEquals('Id', ex.getDmlFieldNames(0).get(0), 'The reported field should be the generic `Id`');
      System.assert(ex.getMessage().contains(
        'If doNotCreateOpportunity is true, opportunityName and opportunityId must be null'
      ), 'Not the expected message was returned');
    }
  }

  /**
   * Existing AccountId and OpportunityId are provided, but the OpportunityName option
   * is also defined, this is an inconsitent state, therefore an exception will be thrown
   */
  @isTest
  static void testConvertLeadToLinkedAccountAndOpportunityAndOpptyName() {
    Account acct = new Account(Name = 'Fry, Sons And Friends');
    insert acct;

    Opportunity oppty = new Opportunity(
      Name = 'Deep Fry',
      AccountId = acct.Id,
      CloseDate = Date.today(),
      StageName = 'Prospecting'
    );
    insert oppty;

    Lead l = new Lead(LastName = 'Fry', Company = 'Fry And Sons');
    insert l;

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    lc.setConvertedStatus(getFirstConvertedStatus());
    lc.setAccountId(acct.Id);
    lc.setOpportunityId(oppty.Id);
    lc.setOpportunityName('New Opportunity Name');

    try {
      Database.LeadConvertResult lcr = Database.convertLead(lc);
      System.assert(false, 'This line should not be reached ' + lcr);
    } catch (DmlException ex) {
      System.assertEquals(1, ex.getNumDml(), 'One DML error should be raised');
      System.assertEquals(StatusCode.INVALID_FIELD, ex.getDmlType(0), 'Invalid field error should be raised');
      System.assertEquals(1, ex.getDmlFieldNames(0).size(), 'One specific field could be reported against');
      System.assertEquals('Id', ex.getDmlFieldNames(0).get(0), 'The reported field should be the generic `Id`');
      System.assert(ex.getMessage().contains(
        'Specify an opportunityId or an opportunityName, but not both'
      ), 'Not the expected message was returned');
    }
  }

  /**
   * Existing AccountId, ContactId and OpportunityId are provided, therefore no new record will be created
   * and existing LeadSource fields will not be not changed when are not null
   */
  @isTest
  static void testConvertLeadToAll() {
    Account acct = new Account(Name = 'Fry, Sons And Friends', AccountSource = 'Account Source');
    insert acct;

    Contact cont = new Contact(
      LastName = 'Deep Fry',
      AccountId = acct.Id,
      LeadSource = 'Contact Lead Source'
    );
    insert cont;

    Opportunity oppty = new Opportunity(
      Name = 'Deep Fry',
      AccountId = acct.Id,
      CloseDate = Date.today(),
      StageName = 'Prospecting',
      LeadSource = 'Opportunity Lead Source'
    );
    insert oppty;

    Lead l = new Lead(LastName = 'Fry', Company = 'Fry And Sons', LeadSource = 'Web');
    insert l;

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    lc.setConvertedStatus(getFirstConvertedStatus());
    lc.setAccountId(acct.Id);
    lc.setContactId(cont.Id);
    lc.setOpportunityId(oppty.Id);

    Database.LeadConvertResult lcr = Database.convertLead(lc);

    System.assert(lcr.isSuccess(), 'Success conversion is expected');

    List<Account> accts = getSavedAccounts();
    List<Contact> conts = getSavedContacts();
    List<Opportunity> oppties = getSavedOpportunities();

    System.assertEquals(1, accts.size(), 'No new account should be created');
    System.assertEquals(1, conts.size(), 'No new contact should be created');
    System.assertEquals(1, oppties.size(), 'No new opportunity should be created');
    System.assertEquals('Account Source', accts.get(0).AccountSource, 'AccountSource should not change');
    System.assertEquals('Contact Lead Source', conts.get(0).LeadSource, 'Contact LeadSource should not change');
    System.assertEquals('Opportunity Lead Source', oppties.get(0).LeadSource, 'Opportunity LeadSource should not change');
  }

  /**
   * Existing AccountId, ContactId and OpportunityId are provided, therefore no new record will be created
   * and existing LeadSource fields will be changed when are not null because or setOverwriteLeadSource(true)
   */
  @isTest
  static void testConvertLeadToAllOverwriteLeadSource() {
    Account acct = new Account(Name = 'Fry, Sons And Friends', AccountSource = 'Account Source');
    insert acct;

    Contact cont = new Contact(
      LastName = 'Deep Fry',
      AccountId = acct.Id,
      LeadSource = 'Contact Lead Source'
    );
    insert cont;

    Opportunity oppty = new Opportunity(
      Name = 'Deep Fry',
      AccountId = acct.Id,
      CloseDate = Date.today(),
      StageName = 'Prospecting',
      LeadSource = 'Opportunity Lead Source'
    );
    insert oppty;

    Lead l = new Lead(LastName = 'Fry', Company = 'Fry And Sons', LeadSource = 'Web');
    insert l;

    Database.LeadConvert lc = new Database.LeadConvert();
    lc.setLeadId(l.Id);
    lc.setConvertedStatus(getFirstConvertedStatus());
    lc.setAccountId(acct.Id);
    lc.setContactId(cont.Id);
    lc.setOpportunityId(oppty.Id);
    lc.setOverwriteLeadSource(true);

    Database.LeadConvertResult lcr = Database.convertLead(lc);

    System.assert(lcr.isSuccess(), 'Success conversion is expected');

    List<Account> accts = getSavedAccounts();
    List<Contact> conts = getSavedContacts();
    List<Opportunity> oppties = getSavedOpportunities();

    System.assertEquals(1, accts.size(), 'No new account should be created');
    System.assertEquals(1, conts.size(), 'No new contact should be created');
    System.assertEquals(1, oppties.size(), 'No new opportunity should be created');
    System.assertEquals('Account Source', accts.get(0).AccountSource, 'AccountSource should change');
    System.assertEquals('Web', conts.get(0).LeadSource, 'Contact LeadSource should change');
    System.assertEquals('Opportunity Lead Source', oppties.get(0).LeadSource, 'Opportunity LeadSource should change');
  }

  private static String getFirstConvertedStatus() {
    LeadStatus convertStatus = [
      SELECT Id, ApiName
      FROM LeadStatus
      WHERE IsConverted = TRUE
      LIMIT 1
    ];
    return convertStatus.ApiName;
  }

  private static List<Account> getSavedAccounts() {
    return [
      SELECT
        Id,
        Name,
        AccountSource,
        (SELECT FirstName, LastName, AccountId FROM Contacts),
        (SELECT Id, Name, AccountId FROM Opportunities)
      FROM Account
      ORDER BY CreatedDate
    ];
  }
  private static List<Contact> getSavedContacts() {
    return [SELECT Id, FirstName, LastName, LeadSource FROM Contact ORDER BY CreatedDate];
  }

  private static List<Opportunity> getSavedOpportunities() {
    return [SELECT Id, Name, AccountId, LeadSource FROM Opportunity ORDER BY CreatedDate];
  }
}
