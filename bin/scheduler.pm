package schedulerFormat;

use strict; use warnings; 
use Cwd; use Spreadsheet::ParseExcel;
$SIG{INT} = \&interrupt;

sub check_sanity {
	my ($professorFile, $studentFile, $projectName) = @_;
	print_usage() and die "\n**Fatal Error: Professor raw file (-p) does not exist!**\n\n" if not -e $professorFile;
	print_usage() and die "\n**Fatal Error: Student raw file (-s) does not exist!**\n\n"   if not -e $studentFile;
	print_usage() and die "\n**Fatal Error: Project name (-n) must be alphanumeric(a-z/0-9)!**\n\n" if ($projectName !~ /^\w+$/);
}

sub print_usage {
	print "\nusage: $0 [options] -p <professor schedule file> -s <student preference file> -n <project name>

-n: Project name is result folder name, must be alphanumeric

options:
-a: Required if professor schedule file is an excel file
-b: Required if student preference file is an excel file


Input format is very straightforward:
--------------------------------------------------------------
All input file must be tab separated format or excel format from doodle.com
Name must not contain non-alphanumeric characters (except \"-\", e.g. John Buck-Doe)
First name and last name must be separated by space (e.g. John Doe instead of John.Doe or JohnDoe)
It's ok if there is only last name (e.g. John)

1. Professor schedule format

FIRSTNAME LASTNAME<TAB>VALUE<TAB>VALUE<TAB>

Example:
Professor name1	OK	OK	OK	OK	OK	OK		OK
Professor name2		OK		OK	OK	OK	OK	
Professor name3	OK		OK	OK	OK	OK		

Explanation:
OK means he/she is available
No value (<TAB><TAB>) means he/she is not available at that timeslot

2. Student preference format:

FIRSTNAME LASTNAME<TAB>FIRSTNAME LASTNAME<TAB>FIRSTNAME LASTNAME<TAB>FIRSTNAME LASTNAME

Example:
Student name1	Professor name1	Professor name2	!Professor name3
Student name2	Professor name3	Professor name4	Professor name1
Student name3	Professor name5	Professor name2	Professor name3

Explanation:
Professor name should be ordered by the student's desire to meet. 
Above, Student_name1 want to meet Professor_name1 the most.

If a professor request to meet a student, put an exclamation mark \"!\" in front of the professor's name.
Above, rofessor_name3 wants to meet Student_name1

Make sure professor name in professor schedule match those in student schedule
E.g. Doesn't match: John Glasser vs John Glaser
--------------------------------------------------------------

";
}

sub define_directory {
	my ($project_name) = @_;
	
	my $current_dir = `pwd` . "/bin/";
	$current_dir =~ s/\n//;
	$current_dir =~ s/bin\/bin/bin/;
	my ($main_dir)  = $current_dir =~ /^(.+)\/bin\/?$/;
	my $result_dir  = $main_dir . "/Result/$project_name/";
	if (not -d $result_dir) {
	        system("mkdir $result_dir") == 0 or die "Cannot create result directory $result_dir: $!\n";
	}
	else {
		print "Warning: Directory exists. Overwrite? (Ctrl+C to cancel, press Enter to Overwrite)";
		<STDIN>;
		print "\n";
	}
	return($main_dir, $result_dir);
}

sub processProfessorTable {
	my ($prof_raw_file, $result_dir, $main_dir, $excel) = @_;

	my %result;
	if ($excel == 1) {
		# Process format error on the raw file
		%result = %{convertProfDoodleExcel($prof_raw_file)};
	}

	# process raw file
	else {
		%result = %{convertProfTSV($prof_raw_file)};
	}

	# get location from professor room file
	my %room;
	open (my $prof_room_final_in, "<", "$main_dir/bin/professor_buildings.txt") or die "Cannot read from $main_dir/bin/professor_buildings.txt: $!\n";
	while (my $line = <$prof_room_final_in>) {
		my ($room, $name, $fullname) = split("\t", $line);
		$room{lc($name)} = $room;
		$room{lc($fullname)} = $room;
	}

	# open out files
	my $professor_table_file_file = "$result_dir\/professor_table_final.txt";
	my $prof_sched_file = "$result_dir\/professor_schedule_final.txt";	
	open (my $professor_table_file_file_out, ">", "$result_dir\/professor_table_final.txt")    or die "Cannot write to $result_dir\/professor_table_final.txt: $!\n";
	open (my $prof_sched_file_out, ">", "$result_dir\/professor_schedule_final.txt") or die "Cannot write to $result_dir\/professor_schedule_final.txt: $!\n";

	# print header
	print $professor_table_file_file_out "\#Professor_Data_Table\n#professor id\tfullname\tname\tdept\n";
	print $prof_sched_file_out "\#Professor_Preference_Table\n\#professor id\tlocation\tslots\n";

	my $professor_number = 0;
	foreach my $name (sort keys %result) {
		my $fullname = lc($result{$name}{full});
		my $location = defined($room{$name}) ? $room{$name} : defined($room{$fullname}) ? $room{$fullname} : "NA";
		print $professor_table_file_file_out "p$professor_number\t$fullname\t$name\t$location\n";
		print $prof_sched_file_out "p$professor_number\t$location\t";
		my @slot = @{$result{$name}{data}};
		for (my $i = 0; $i < @slot; $i++) {
			$slot[$i] = 0 if $slot[$i] ne 1;
			print $prof_sched_file_out "$slot[$i]";
			my $endline = $i == @slot - 1 ? "\n" : "\t";
			print $prof_sched_file_out "$endline";
		}
		$professor_number++;
	}
}

sub processStudentTable {
	my ($student_file, $result_dir, $excel) = @_;

	my $professor_table_file = "$result_dir\/professor_table_final.txt";
	open (my $professor_table_file_in, "<", $professor_table_file) or die "Cannot read from $professor_table_file: $!\n";
	# Process professor table
	#professor_id	fullname	name	dept
	my %prof;
	while (my $line = <$professor_table_file_in>) {
		chomp($line);
		$line = lc($line);
		next if $line =~ /\#/; #header
		my ($id, $fullname, $name) = split("\t", $line);
		$prof{$name}{id}     = $id;
		$prof{$fullname}{id} = $id;
	}
	close $professor_table_file_in;

	my %result;
	if ($excel == 1) {
		%result = %{convertStudExcel($student_file)};
	}
	else {
		%result = %{convertStudTSV($student_file)};
	}	

	open (my $spref_out, ">", "$result_dir\/student_preference_final.txt") or die "Cannot write to student_preference_final.txt: $!\n";
	open(my $stable_out, ">", "$result_dir\/student_table_final.txt") or die "Could not write into $result_dir\/student_table_final.txt\n";
	# print header
	print $stable_out "#Student_Data_Table\n\#student id\tfullname\tname\n";
	print $spref_out "#Student_Preference_Table\n\#student id\tprofessor ids\n";

	my $student_number = 0;
	my @prof_without_schedule;
	foreach my $name (sort keys %result) {
		my $fullname = $result{$name}{full};
		print $stable_out "s$student_number\t$fullname\t$name\n";

		my @data     = @{$result{$name}{data}};
		my @fulldata = @{$result{$name}{fulldata}};
		print $spref_out "s$student_number\t";
		for (my $i = 0; $i < @data; $i++) {
			my $profname = lc($data[$i]);
			my $proffullname = lc($fulldata[$i]);
			my ($tempname) = $profname =~ /^!?(.+)$/;
			my ($tempfullname) = $proffullname =~ /^!?(.+)$/;

			# Record in @prof_without_schedule and next if a student request to meet with a professor without known schedule
			my $special = $proffullname =~ /!/ ? "!" : "";
			my $endline = $i == @data - 1 ? "\n" : "\t";
			if (defined($prof{$tempfullname}{id})) {
				print $spref_out "$special$prof{$tempfullname}{id}$endline";
			}
			elsif (defined($prof{$tempname}{id})) {
				print $spref_out "$special$prof{$tempname}{id}$endline";
			}
			else {
				push(@prof_without_schedule, "$data[$i]\t$fulldata[$i]") if not grep(/^$data[$i]\t$fulldata[$i]$/, @prof_without_schedule);
				print $spref_out "$endline" if $i == @data - 1;
			}
		}
		$student_number++;
	}
	close $stable_out;
	close $spref_out;

	open (my $out2, ">", "$result_dir\/professor_without_schedule.txt") or die "Cannot write to $result_dir\/professor_without_schedule.txt: $!\n";
	print $out2 "\#List of professor without schedule
\#Name\tFull_Name
\#If you find professor here that do have schedule, make sure that the professor names in both raw files match each other
\#E.g. Doesn't match: John Glasser vs John Glaser\n";
	for (my $i = 0; $i < @prof_without_schedule; $i++) {
		print $out2 "$prof_without_schedule[$i]\n";
	}

}

sub processProfessorDemand {
	my ($student_pref_file, $result_dir) = @_;

	# Print to professor_preference_final.txt
	open (my $student_pref_file_in, "<", $student_pref_file) or die "Cannot read from $student_pref_file: $!\n";
	open (my $ppref_out, ">", "$result_dir\/professor_preference_final.txt") or die "Cannot write to professor_preference_final.txt: $!\n";
	my %ppref;
	while (my $line = <$student_pref_file_in>) {
		chomp($line);
		next if $line =~ /\#/; #header
		my ($student_id, @prof) = split("\t", $line);

		for (my $i = 0; $i < @prof; $i++) {
			my $prof_id = $prof[$i];
			my ($temp_prof_id) = $prof_id =~ /^!?(\w+)$/;
			# If there is a star, this prof want to meet the student, therefore record in %ppref
			push(@{$ppref{$temp_prof_id}}, $student_id) if $prof[$i] =~ /^\!/;
		}
	}
	close $student_pref_file_in;

	print $ppref_out "\#Professor Preference Final\nProfessor_id\tStudent_ids\n";
	foreach my $prof_id (sort keys %ppref) {
		print $ppref_out "$prof_id";
		foreach my $student (sort @{$ppref{$prof_id}}) {
			print $ppref_out "\t$student";
		}
		print $ppref_out "\n";
	}
}

sub convertProfDoodleExcel {	
	my ($excelFile) = @_;

	my %result;
	my $excel = new Spreadsheet::ParseExcel;
	my $data  = $excel->Parse($excelFile);

	my @result;
	for my $worksheet ($data->worksheets()) {
		
		my ($row_min, $row_max) = $worksheet->row_range();
		my ($col_min, $col_max) = $worksheet->col_range();
	
		# Get data by column
		# Col\Row	A	B	C 
		#     	1	Dat	Dat	Dat  ->
		#	2	Dat	Dat	Dat
		#
		# Doodle data always starts at 7th row, therefore start from i = 6
		# Doodle data at $row_max is Count table, therefore end at $i == $row_max - 1
	
		for (my $i = 6; $i < $row_max; $i++) {
			my $line;
			for (my $j = $col_min; $j <= $col_max; $j++) {
				my $cell = $worksheet->get_cell($i,$j);
				my $value;
				if (defined($cell)) {
					$value = $cell->value();
					$value = 1 if $value eq "OK";
					$value = 0 if $value eq "";

				}
				else {
					$value = "";
				}
				$line .= "$value";
				if ($j != $col_max) {
					$line .= "\t";
				}
				my ($name, @arr) = split("\t", $line);
				@{$result{$name}} = @arr;
			}
		}
	}
	%result = %{convertProfname(\%result)};
	return(\%result);
}

sub convertProfTSV {
	my ($fh) = @_;

	my %result;
	my $data;
	open (my $in, "<", "$fh") or die "Cannot read from $fh: $!\n";
	while (my $line = <$in>) {
		$data .= $line;
	}
	close $in;
	$data =~ s/\r\n/\n/g;
	$data =~ s/\r/\n/g;

	my @line = split("\n", $data);
	for (my $i = 0; $i < @line; $i++) {
		my $line = $line[$i];
		$line =~ s/\tOK/\t1/ig;
		$line =~ s/\t\t/\t0\t/ig;
		$line =~ s/\t$/\t0/ig;
		my ($name, @arr) = split("\t", $line);
		@{$result{$name}} = @arr;
	}
	close $in;
	%result = %{convertProfname(\%result)};
	return(\%result);
}

sub convertStudExcel {	
	my ($excelFile) = @_;

	my %result;
	my $excel = new Spreadsheet::ParseExcel;
	my $data  = $excel->Parse($excelFile);

	my @result;
	for my $worksheet ($data->worksheets()) {
		
		my ($row_min, $row_max) = $worksheet->row_range();
		my ($col_min, $col_max) = $worksheet->col_range();
	
		# Get data by column
		# Col\Row	A	B	C 
		#     	1	Dat	Dat	Dat  ->
		#	2	Dat	Dat	Dat
		#
	
		for (my $i = $row_min; $i < $row_max; $i++) {
			my $line;
			for (my $j = $col_min; $j <= $col_max; $j++) {
				my $cell = $worksheet->get_cell($i,$j);
				my $value;
				if (defined($cell)) {
					$value = $cell->value();
				}
				else {
					$value = "";
				}

				$line .= "$value";
				if ($j != $col_max) {
					$line .= "\t";
				}
				
				my ($name, @prof) = split("\t", $line);
				%result = (%result, %{convertStudname($name, \@prof)});
			}

		}
	}
	return(\%result);
}

sub convertStudTSV {
	my ($fh) = @_;
	my %result;
	my $data;
	open (my $in, "<", "$fh") or die "Cannot read from $fh: $!\n";
	while (my $line = <$in>) {
		$data .= $line;
	}
	close $in;
	$data =~ s/\r\n/\n/g;
	$data =~ s/\r/\n/g;
	
	my @line = split("\n", $data);
	for (my $i = 0; $i < @line; $i++) {
		my $line = $line[$i];
		next if $line =~ /^\#/;
		my ($name, @prof) = split("\t", $line);
		%result = (%result, %{convertStudname($name, \@prof)});
	}
	close $in;
	return(\%result);
	die;
}

sub convertStudname {
	my ($name, $prof) = @_;
	my %result;
	my ($newname) = fix_name($name);
	my @prof = @{$prof};
	my @newprof;
	for (my $i = 0; $i < @prof; $i++) {
		my ($newprof, $special) = fix_name($prof[$i]);
		push(@newprof, "!$newprof") if $special == 1;
		push(@newprof, "$newprof")  if $special == 0;
	}
	$result{$newname}{full} 	= $name;
	@{$result{$newname}{data}}	= @newprof;
	@{$result{$newname}{fulldata}}  = @prof;
	return(\%result);
}
sub convertProfname {
	my ($result) = @_;
	my %result = %{$result};

	my %temp;
	foreach my $name (sort keys %result) {
		my @slot = @{$result{$name}};
		my ($newname) = fix_name($name);
		my $tempname = $newname;
		my $count = "";
		while (defined($temp{$tempname})) {
			$count++;
			$tempname = "$newname$count";
		}
		$temp{$tempname}{data} = $result{$name};
		$temp{$tempname}{full} = $name;
	}

	%result = %temp;
	return(\%result);
}

sub fix_name {
	my ($name) = @_;
	my $special = 0;
	my $temp = lc($name);
	$special = 1 if $temp =~ /^\!/;
	$temp =~ s/[\(\)\/\\\-\.\!]//g;
	my @name = split(" ", $temp);
	my $newname;
	if (@name == 1) {
		$newname = $name[0];
	}
	else {
		my ($first, $last) = ($name[0], $name[@name-1]);
		($first) = $first =~ /^(\w)/;
		die "Died at $name\n" unless defined($first);
		$newname = $first . $last;
	}
	return($newname, $special);
}
sub interrupt {
	print STDERR "\n\nScript cancelled\n\n";
	exit;
}

package fitnessfunc;

use strict; use warnings;

=head2 Description

Fitness function perl module is a list of subroutines that
can be used to assess each genome based on certain preferences.

Currently, the preferences are B<Conflicting Schedules>, B<Prof Schedules>,
B<Prof Preferences>, B<Student Preferences>, and B<Distance Between Offices>.

=cut

# Global score is 9000
my $global_score = 9000;

=head2 Function conflict_test

Returns a fitness score I<$score> from schedule I<$schedule>

I<$schedule> is a hash of schedule

Currently the data structure is C<$schedule{data}{$prof}{$slot} = "$student";>

Slot is 0-5
Example: C<$schedule{data}{p1}{$j} = "s1";>

=cut

sub conflict_test {
	my ($schedule) = @_;
	my %schedule = %{$schedule};
	my $score = $global_score;
	#Open by each genome
	#Now is the main function to score
	#If there is conflicting schedule we minus 10%

	# 1. Does each prof has more than 1 student?
	my %prof;
	# 2. Does each student has more than 1 identical time schedule?
	my %student;
	foreach my $prof (sort keys %{$schedule{data}}) {
		foreach my $slot (sort keys %{$schedule{data}{$prof}}) {
			my $student = $schedule{data}{$prof}{$slot};
			$prof{$prof}{$student}++;
			$student{$student}{$slot}++;
		}
	}

	# Calculate score where each conflict is -10
	foreach my $prof (keys %prof) {
		foreach my $student (keys %{$prof{$prof}}) {
			$score -= 0.5*$global_score*($prof{$prof}{$student}-1);
		}
	}
	foreach my $student (keys %student) {
		foreach my $slot (keys %{$student{$student}}) {
			$score -= 0.5*$global_score*($student{$student}{$slot}-1);
		}
	}
	return($score);
}

=head2 Function prof_schedule_score

Returns a fitness score I<$score> from schedule I<$schedule>
based on professor schedule I<$p_sched>

I<$schedule> is a hash of schedule

Currently the data structure is C<$p_sched{$prof}{$slot} = "$availability";>, where 0 is unavailable and 1 is available.

Example: C<$p_sched{p1}{$i} = "0";>

=cut

sub prof_schedule_score {
	my ($schedule, $score, $p_sched) = @_;
	my %schedule = %{$schedule};
	my %p_sched = %{$p_sched};
	my $numofna = 0;

	# 1. Does schedule match the professor's slot?
	foreach my $prof (sort keys %{$schedule{data}}) {
		foreach my $slot (sort {$a <=> $b} keys %{$schedule{data}{$prof}}) {
			my $student = $schedule{data}{$prof}{$slot};
			die "student not defined\n" if not defined($student);
			die "Professor $prof schedule (starting at slot $slot) is not correct format\n" if not defined($p_sched{$prof}{$slot});
			if ($student ne "NA" and $p_sched{$prof}{$slot} == 0) {
				$numofna++;

				# If no, then minus 5% of global score
				$score -= (1*$global_score)*(2**$numofna);
			}
			else {
				#$score += 0.1*$global_score;
			}
		}
	}
	return($score);
}

=head2 Function prof_preference_score

Returns a fitness score I<$score> from schedule I<$schedule>
based on professor schedule I<$p_pref>

I<$schedule> is a hash of schedule

Currently the data structure is C<@{$p_pref{$prof}} = @students_to_meet;> where students to meet array ranges from 0-6.

Example: C<$p_pref{p1}[0] = "s1";>

=cut

sub prof_preference_score {
	my ($schedule, $score, $p_pref) = @_;
	my %schedule = %{$schedule};
	my %p_pref = %{$p_pref};
	foreach my $prof (sort keys %p_pref) {
		my $match = 0;
		my @students = @{$p_pref{$prof}};
		next if @students == 0;

		# Add 5% global score if prof meet the student
		my @studentunique;
		foreach my $students (@students) {
			next if $students eq "NA";
			foreach my $slot (sort {$a <=> $b} keys %{$schedule{data}{$prof}}) {
				my $student = $schedule{data}{$prof}{$slot};
				next if $student eq "NA";
				if (grep (/^$student$/i, @students) and not grep(/^$student$/i, @studentunique)) {
					push(@studentunique, $student);
					$score += 0.5*$global_score;
					$match++;
				}
			}
		}

		# Reduce 5% global score if prof doesnt meet the student
		$score -= 0.05*$global_score*(@students - $match);
	}
	return($score);
}

=head2 Function stud_schedule_score

Returns a fitness score I<$score> from schedule I<$schedule>
based on student preference I<$s_pref>

I<$s_pref> is a hash of schedule

Currently the data structure is C<$s_pref{$stud}{$prof} = "$prof_score";>

Example: C<$s_pref{s1}{p1} = "9";>

=cut


sub stud_preference_score {
	my ($schedule, $score, $s_pref) = @_;
	my %schedule = %{$schedule};
	my %s_pref = %{$s_pref};
 
	foreach my $prof (sort keys %{$schedule{data}}) {
		foreach my $slot (sort {$a <=> $b} keys %{$schedule{data}{$prof}}) {
			my $student = $schedule{data}{$prof}{$slot};
			# If prof exists in student pref then plus prof_score/10 * 2%
			if (defined($s_pref{$student}{$prof})) {
				my $prof_score = $s_pref{$student}{$prof};
				$score +=  0.5*$prof_score*0.02*$global_score;
			}
			
		}
	}
	return($score);
}

=head2 Function get_distance_score

Returns a fitness score I<$score> from schedule I<$schedule>

Asses each location of each student's slot based on I<$schedule>
based on distance matrix I<$dmat> of each professor's location I<$p_table>

I<$dmat> is a hash of distance matrix

Currently the data structure is C<$dmat{$location1}{$location2} = $minutes;>

I<$p_table> is a hash of professor table

Currently the data structure is C<$p_table{$prof}{name} = "name"; $p_table{$prof}{place} = "place";>

Example: C<$p_table{p1}{name} = "sabel"; $ptable{p1}{place} = "Briggs";>

=cut

sub get_distance_score {
	my ($schedule, $score, $dmat, $p_table) = @_;
	# P_table format; $p_table{p1}{name} and $p_table{p1}{place}
	my %p_table = %{$p_table};
	my %dmat = %{$dmat};
	my %schedule = %{$schedule};

	# Convert prof schedule to student schedule
	my %ssched; # Student Schedule
	foreach my $prof (sort keys %{$schedule{data}}) {
		foreach my $slot (sort {$a <=> $b} keys %{$schedule{data}{$prof}}) {
			my $student = $schedule{data}{$prof}{$slot};
			next if $student eq "NA";
			$ssched{data}{$student}{$slot} = $prof;
		}
	}
	# Add NA to student schedule with no prof
	foreach my $student (keys %{$ssched{data}}) {
		for (my $i = 0; $i < 6; $i++) {
			$ssched{data}{$student}{$i} = "NA" if not defined($ssched{data}{$student}{$i});
		}
	}

	# Assess student schedule and add/sub score accordingly
	foreach my $student (sort keys %{$ssched{data}}) {
		my $loc0 = defined($p_table{$ssched{data}{$student}{0}}{place}) ? $p_table{$ssched{data}{$student}{0}}{place} : "NA";
		my $loc1 = defined($p_table{$ssched{data}{$student}{1}}{place}) ? $p_table{$ssched{data}{$student}{1}}{place} : "NA";
		my $loc2 = defined($p_table{$ssched{data}{$student}{2}}{place}) ? $p_table{$ssched{data}{$student}{2}}{place} : "NA";
		my $loc3 = defined($p_table{$ssched{data}{$student}{3}}{place}) ? $p_table{$ssched{data}{$student}{3}}{place} : "NA";
		my $loc4 = defined($p_table{$ssched{data}{$student}{4}}{place}) ? $p_table{$ssched{data}{$student}{4}}{place} : "NA";
		my $loc5 = defined($p_table{$ssched{data}{$student}{5}}{place}) ? $p_table{$ssched{data}{$student}{5}}{place} : "NA";
			
		# Location each #
		my %loc;
		$loc{01} = defined($dmat{$loc0}{$loc1}) ? $dmat{$loc0}{$loc1} : "NA";
		$loc{02} = defined($dmat{$loc0}{$loc2}) ? $dmat{$loc0}{$loc2} : "NA";
		$loc{12} = defined($dmat{$loc1}{$loc2}) ? $dmat{$loc1}{$loc2} : "NA";
		$loc{23} = defined($dmat{$loc2}{$loc3}) ? $dmat{$loc2}{$loc3} : "NA";
		$loc{34} = defined($dmat{$loc3}{$loc4}) ? $dmat{$loc3}{$loc4} : "NA";
		$loc{35} = defined($dmat{$loc3}{$loc5}) ? $dmat{$loc3}{$loc5} : "NA";
		$loc{45} = defined($dmat{$loc4}{$loc5}) ? $dmat{$loc4}{$loc5} : "NA";

		foreach my $loc (keys %loc) {
			if ($loc{$loc} ne "NA") {
				# 1. Penalty if distance is too large between slot 012 or 345 if ($loc3 
				$score -= $loc{$loc}**2 /20 * 0.01 * $global_score if $loc ne "23" and $loc{$loc} ne "NA";
	
				#2. Reward if the distance between 3 and 4 is large
				$score += $loc{$loc}**2/20 * 0.02 * $global_score if $loc eq "23" and $loc{$loc} ne "NA";
				# 3. Penalty if there is NA in between schedule?
				# 4. Reward if all last schedule is NA?
	
			}
		}
	}
	return($score);
}
1;


__END__
