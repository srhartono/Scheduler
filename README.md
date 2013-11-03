#Interview Scheduler ver 0.5b

#A. Authors
Stella Hartono (srhartono@ucdavis.edu)
Linda Su-Feher (lsu@ucdavis.edu)
Ravi Dandekar (rdandekar@ucdavis.edu)

#B. Function

Automatically create a schedule of interviews based on certain parameters:
- professor preferences to student
- professor availabilities
- student preferences to professor
- distance between interview locations


#C. Input

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

#E. Formatting

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
If a professor request to meet a student, put an exclamation mark \"!\" in front of the professor's name. For example at above, rofessor_name3 wants to meet Student_name1.

#D. How to install:  
1. Install github (www.github.com)
2. Clone this repo `git clone https://github.com/srhartono/Scheduler`
3. Run 1_Process_Inpput.pl with your input files and project name, and it will produce the necessary files. This only need to be done once.
4. Then run 2_Scheduler.pl from Result/<Project Name> folder

#F. Example

```
bin/1_Process_Input.pl -a -b -p Data/Example/Prof.xls -s Data/Example/Stud.xls -n Example
bin/2_Scheduler.pl -d Result/Example/ -g 100 -p 100 -s 0.1
#Best schedule output is at Result/Example/best_schedule.txt
```

#G Advanced

##To add/remove professor location:  

1. Go to bin/
2. Edit bin/professor_buildings.txt
3. Add building, lowercase first character of first name and last name, then complete name

Example:   
`Building	jdoe	John Doe`

##To add/remove building GPS location:  

1. Go to bin/GPSmatrixgen/
2. Edit gpscoords.txt and add building, longitute, and latitude in tab separate format
3. Run gpsmatrix.pl with gpscoords.txt as input to produce distcoords.txt

Example:  
`Building	-121.00124	38.235`
