##Interview Scheduler ver 0.5b

##A. Authors   
1. Stella Hartono (srhartono@ucdavis.edu)
2. Linda Su-Feher (lsu@ucdavis.edu)
3. Ravi Dandekar (rdandekar@ucdavis.edu)

##B. Function

Automatically create a schedule of interviews based on certain parameters:
- professor preferences to student
- student preferences to professor
- professor availabilities
- distance between interview locations

##C. Input

Input files are two files:  
1. Professor schedule/availability
2. Student preference

#D. Important Notes

1. Must be Unix based OS
2. All input file must be tab separated format or excel format from doodle.com
3. Name MUST NOT contain non-alphanumeric characters (except \"-\", e.g. John Buck-Doe)
4. First name and last name MUST be separated by space (e.g. John Doe instead of John.Doe or JohnDoe)
5. Make sure professor name in professor schedule match those in student preference otherwise it won't work
6. It's ok if there is only one name (e.g. John)

##E. Formatting

**1. Professor schedule format:**  

`FIRSTNAME LASTNAME<TAB>VALUE<TAB>VALUE<TAB>`

```
Professor name1 OK      OK      OK      OK      OK      OK              OK
Professor name2         OK              OK      OK      OK      OK
Professor name3 OK              OK      OK      OK      OK
```

Explanation:  
OK means he/she is available  
No value (<TAB><TAB>) means he/she is not available at that timeslot

**2. Student preference format:**  

`FIRSTNAME LASTNAME<TAB>FIRSTNAME LASTNAME<TAB>FIRSTNAME LASTNAME`

```
Student name1   Professor name1 Professor name2 !Professor name3
Student name2   Professor name3 Professor name4 Professor name1
Student name3   Professor name5 Professor name2 Professor name3
```

Explanation:  
Professor name should be ordered by the student's desire to meet. For example at above, Student_name1 want to meet Professor_name1 the most.  
If a professor request to meet a student, put an exclamation mark "!" in front of the professor's name. For example at above, professor_name3 wants to meet Student_name1.

##D. How to install:  
1. Install github (www.github.com)
2. Clone this repo `git clone https://github.com/srhartono/Scheduler`
3. Run 1_Process_Inpput.pl with your input files and project name, and it will produce the necessary files. This only need to be done once.
4. Then run 2_Scheduler.pl from Result/<Project Name> folder

##F. Example

```
bin/1_Process_Input.pl -a -b -p Data/Example/Prof.xls -s Data/Example/Stud.xls -n Example
bin/2_Scheduler.pl -d Result/Example/ -g 100 -p 100 -s 0.1
#Best schedule output is at Result/Example/best_schedule.txt
```

##G. Advanced

###To add/remove professor location:  

1. Go to bin/
2. Edit bin/professor_buildings.txt
3. Add building, lowercase first character of first name and last name, then complete name

Example:   
`Building	jdoe	John Doe`

###To add/remove building GPS location:  

1. Go to bin/GPSmatrixgen/
2. Edit gpscoords.txt and add building, longitute, and latitude in tab separate format
3. Run gpsmatrix.pl with gpscoords.txt as input to produce distcoords.txt

Example:  
`Building	-121.00124	38.235`
  
###H. Output Example

The script will produce the best schedule and a graph (Score.pdf) showing the scores per generation. Example:

```
# Score: 188.291
# Best Professor Schedule
|Professor  |Slot1| Slot2 |Slot3 |Slot4|
|:-------------:|:-------------:|:-------------:|:-------------:|
|Alan Rose|       Peter Parker|    Clark Kent|      Bruce Wayne|     NA|
|Chengji Zhou |   NA     | NA   |   Clark Kent    |  Peter Parker|
|Dan Kliebenstein |       Tony Stark  |    NA  |    Bruce Wayne   |  Peter Parker|
|Dan Parfitt    | Robert Bruce Banner  |   Peter Parker |   Clark Kent    |  NA|
|David Segal   |  NA  |    NA  |    NA  |    Tony Stark|
|Dan Starr    |   Clark Kent  |    Bruce Wayne  |   NA |     NA|
|Fred Chedin  |   NA|      Robert Bruce Banner |    Peter Parker  |  NA|
|Ian Korf      |  Clark Kent |     NA   |   Tony Stark  |    Robert Bruce Banner|
|Julin Maloof |   Bruce Wayne   |  Tony Stark    |  Peter Parker  |  NA|
|Lesilee Rose  |  NA    |  NA   |   NA      |Clark Kent|
|Richard Michelmore   |   NA  |    Peter Parker   | Robert Bruce Banner |    NA|
|Tom Glaser|      Clark Kent  |    NA    |  Tony Stark    |  Bruce Wayne|

# Best Student Schedule
Bruce Wayne     Julin Maloof    Dan Starr       Dan Kliebenstein        Tom Glaser
Clark Kent      Tom Glaser      Alan Rose       Dan Parfitt     Lesilee Rose
Peter Parker    Alan Rose       Richard Michelmore      Julin Maloof    Dan Kliebenstein
Robert Bruce Banner     Dan Parfitt     Fred Chedin     Richard Michelmore      Ian Korf
Tony Stark      Dan Kliebenstein        Julin Maloof    Tom Glaser      David Segal

# Location
Bruce Wayne     LSA     Briggs  Admuns  Tupper
Clark Kent      Tupper  Briggs  Wickson LSA
Peter Parker    Briggs  GBSF    LSA     Admuns
Robert Bruce Banner     Wickson Briggs  GBSF    GBSF
Tony Stark      Admuns  LSA     Tupper  GBSF
```
