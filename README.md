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

## Introduction
Unfortunatelly, Apex internal codebase doesn't tackle this conversion the best way. We'll briefly discuss here how `Database.LeadConvert` seems to hurt quite a few best practices and principles and how poor the decision to delegate all the validations to `Database.convertLead()` is, as it requires all the burden of a database call to realise there could be a mistaken setup.

Windfarm is a way to both help build the conversion setup and to check for errors before hitting the database, consequently keeping your code lightweight.  

**Deploy this to your Salesforce Org:**

[![Deploy to Salesforce](https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png)](https://githubsfdeploy.herokuapp.com/?owner=berardo&repo=apex-windfarm&ref=master)

## Overview

