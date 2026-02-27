# Challenge 01: Data Detective

**Difficulty:** Beginner | **Time:** 10 minutes | **Skills:** `/eda`, `/data-quality`

---

## Scenario

Your manager just forwarded you a customer export from the CRM team. "Can you
load this into our analytics database? It should be clean — they said they
already validated it."

You've been around long enough to know that "already validated" usually means
"nobody checked." Your job: find the data quality issues before they pollute
downstream reports.

---

## The Dataset

Save the CSV below to a file called `crm_export.csv`, then use Claude Code to
analyze it.

```csv
customer_id,first_name,last_name,email,age,city,signup_date,lifetime_value
1001,Alice,Chen,alice.chen@example.com,34,San Francisco,2024-03-15,1250.00
1002,Bob,Martinez,bob.martinez@example.com,28,New York,2024-04-22,890.50
1003,Carol,Johnson,carol.j@example.com,45,Chicago,2024-01-10,3200.00
1004,David,Kim,david.kim@example,31,Los Angeles,2024-06-01,450.00
1005,Eve,Patel,eve.patel@example.com,29,Seattle,2024-05-18,2100.75
1006,Frank,Lopez,FRANK.LOPEZ@EXAMPLE.COM,52,Houston,2024-02-28,1800.00
1007,Grace,Williams,grace.w@example.com,-3,Phoenix,2024-07-04,670.25
1008,Henry,Brown,henry.brown@example.com,41,Denver,2024-03-30,920.00
1009,Iris,Davis,iris.davis@example.com,36,Boston,2024-08-15,1550.00
1010,Jack,Wilson,jack.wilson@example.com,38,Portland,2024-04-10,1100.00
1001,Alice,Chen,alice.chen@example.com,34,San Francisco,2024-03-15,1250.00
1011,Karen,Taylor,karen.t@example.com,27,Austin,2024-09-01,780.00
1012,Leo,Anderson,leo.anderson@example.com,44,Nashville,2024-06-20,2400.00
1013,Mia,Thomas,mia.thomas@example.com,33,,2024-05-05,1650.00
1014,Noah,Garcia,noah.garcia@example.com,55,Miami,2024-01-25,3800.00
1015,Olivia,Martinez,olivia.m@example.com,31,San Diego,2027-11-15,950.00
1016,Pete,Robinson,pete.robinson@example.com,29,Dallas,2024-07-22,1200.00
1017,Quinn,Clark,quinn.clark@example.com,37,Minneapolis,2024-04-18,1875.50
1018,Rosa,Lewis,rosa.lewis@example.com,42,Atlanta,2024-10-03,2050.00
1019,Sam,Lee,,48,Detroit,2024-03-12,1425.00
1020,Tina,Walker,tina.walker@example.com,30,Columbus,2024-08-28,890.75
1021,Uma,Hall,uma.hall@EXAMPLE.COM,26,Charlotte,2024-06-15,560.00
1022,Victor,Allen,victor.allen@example.com,39,Indianapolis,2024-02-14,1750.00
1023,Wendy,Young,wendy.young@example.com,-7,Raleigh,2024-09-20,1320.00
1024,Xavier,King,xavier.king@example.com,35,Salt Lake City,2024-05-30,2200.00
1025,Yara,Wright,yara.wright@example.com,43,,2024-04-08,1680.00
1026,Zach,Scott,zach.scott@example.com,51,Tampa,2024-07-14,3100.00
1027,Amy,Green,amy.green@example.com,28,Orlando,2024-11-01,420.00
1028,Ben,Adams,Ben.Adams@Example.Com,33,Sacramento,2024-06-25,1550.00
1029,Cora,Nelson,cora.nelson@example.com,40,Kansas City,2024-03-05,1900.00
1030,Dan,Hill,dan.hill@example.com,46,Cincinnati,2024-08-10,2350.00
1002,Bob,Martinez,bob.martinez@example.com,28,New York,2024-04-22,890.50
1031,Ella,Baker,ella.baker@example.com,22,Pittsburgh,2024-10-15,310.00
1032,Finn,Rivera,finn.rivera@example.com,37,San Jose,2024-05-22,1470.00
1033,Gina,Campbell,gina.campbell@example.com,54,Milwaukee,2024-02-18,2800.00
1034,Hugo,Mitchell,hugo.mitchell@example.com,30,Virginia Beach,2024-09-08,825.00
1035,Ivy,Roberts,ivy.roberts@example.com,41,Tucson,2024-04-30,1600.00
1036,Jake,Carter,jake.carter@example.com,36,Omaha,2024-07-02,1150.00
1037,Kira,Phillips,kira.phillips@example.com,25,Albuquerque,2024-11-20,280.00
1038,Luke,Evans,luke.evans@example.com,47,Fresno,2024-06-10,2100.00
1039,Maya,Turner,maya.turner@example.com,32,Mesa,2024-03-22,1350.00
1040,Nate,Torres,nate.torres@example.com,38,Long Beach,2024-08-05,1750.00
1013,Mia,Thomas,mia.thomas@example.com,33,,2024-05-05,1650.00
1041,Opal,Parker,opal.parker@example.com,29,Virginia Beach,2024-10-30,680.00
1042,Phil,Collins,phil.collins@example.com,44,Oakland,2024-05-15,2450.00
1043,Ruby,Stewart,ruby.stewart@example.com,35,Tulsa,2024-07-28,1280.00
1044,Seth,Sanchez,seth.sanchez@example.com,50,Wichita,2024-02-08,3500.00
1045,Tara,Morris,tara.morris@example.com,27,Arlington,2024-09-12,920.00
```

---

## Your Mission

Find the **3 categories of data quality issues** hidden in this dataset. For
each one:

1. **Identify** the type of issue
2. **List** the specific rows affected
3. **Write** a cleaning script (SQL or Python) that fixes each issue

### Hints

- Start with `/eda` to get a profile of the dataset
- Then run `/data-quality` for a targeted scan
- Think about: uniqueness, validity, completeness, and consistency

---

## Success Criteria

You've completed this challenge when you can name all three issue categories
and have a working cleaning script. The issues are:

- [ ] Issue category 1 found and documented
- [ ] Issue category 2 found and documented
- [ ] Issue category 3 found and documented
- [ ] Cleaning script written and tested

**Bonus:** Can you find more than 3? There are a few subtler problems hiding
in plain sight.
