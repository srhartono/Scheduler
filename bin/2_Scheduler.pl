#!/usr/bin/perl
#################################################
#       Interview Scheduler ver 0.5b            #
# The purpose is to automatically create a      #
# schedule of interviews based on certain       #
# parameters:                                   #
# - professor preferences to student            #
# - professor availabilities                    #
# - student preferences to professor            #
# - distance between interview locations        #
# Authors:                                      #
# Stella Hartono (srhartono@ucdavis.edu)        #
# Linda Su-Fehrer (lsu@ucdavis.edu)             #
# Ravi Dandekar (rdandekar@ucdavis.edu)         #
#################################################

##################################
# 2_Scheduler.pl		 #
# This is the main script that 	 #
# uses Genetic Algorithm to find #
# the best schedule		 #
##################################

my $bin_dir;
BEGIN {
        $bin_dir = `pwd` . "/bin/";
        $bin_dir =~ s/\n//;
        $bin_dir =~ s/bin\/bin/bin/;
        push (@INC, $bin_dir);
}

use strict; use warnings FATAL => 'all';
use scheduler;
use Getopt::Std;
use vars qw($opt_d $opt_g $opt_p $opt_s $opt_v);
getopts("d:g:p:s:v");

# Usage
my ($dir, $generation, $pop_size, $selection_threshold) = ($opt_d, $opt_g, $opt_p, $opt_s);

check_input_correctness($dir, $generation, $pop_size, $selection_threshold);


# First, process the data files	   #

=head1 Processing Data Files

Data files is at $dir

=cut

# Hash of Data
my ($p_sched, $p_table, $p_pref, $s_table, $s_pref, $dmat, $p_loc) = process_data_files($dir);
my %p_sched  = %{$p_sched};
my %p_table  = %{$p_table};
my %p_pref   = %{$p_pref} ;
my %s_table  = %{$s_table};
my %s_pref   = %{$s_pref} ;
my %dmat     = %{$dmat}   ;
my %p_loc    = %{$p_loc}  ;

# Array of student and professor
my @gen_stud = qw(NA);
my @gen_prof;
for (my $i = 0; $i < (keys %s_table); $i++) {
	push(@gen_stud, "s$i");
}
for (my $i = 0; $i < (keys %p_table); $i++) {
	push(@gen_prof, "p$i");
}


# Generation iterator
my $iterator;
$iterator = 1 if $generation != 0;
$iterator = -1 if $generation == 0;

# Generate Random Schedule

=head1 Random Schedule Generator

Generate unseeded random schedules based on current professors and students, plus NA

=cut

my %schedules = %{generate_random_schedules()};
my $prev_average_best_fit_score;

# Calculate score based on fitnessfunc.pm, then select_and_breed, for $generation number of times
my $prev_score = 0;
my @score;
for (my $i = 0; $i <= $generation; $i+=$iterator) {


	my $schedules = \%schedules;

	# Sort and calculate previous generation average best fit score

	if ($i == 0) {
		$schedules = calculate_fitness($schedules);
		($schedules, $prev_average_best_fit_score) = sort_schedule($schedules);
	}

	# Select and Breed
	$schedules = select_and_breed($schedules);

	# Sort and calculate next generation average best fit score
	my $next_average_best_fit_score;
	$schedules = calculate_fitness($schedules);
	($schedules, $next_average_best_fit_score) = sort_schedule($schedules);
	%schedules = %{$schedules};
	my $buffer_score = int(2000000 + $next_average_best_fit_score)/10000;
	my $addition = int(($buffer_score - $prev_score)*100)/100;
	$prev_score = $buffer_score if $i != 0;

	# Plot at last generation
	push(@score, $buffer_score) if $i != 0;
	if ($i == $generation and $i != 0) {
		plot_score(@score);
	}
	
	# Plot every 2^n generation if -g is 0 (unlimited generation)
	if ($generation == 0 and $i != 0 and (log(abs($i))/log(2)) =~ /^\d+$/) {
		plot_score(@score);
	}
	
	# Mutate
	$schedules = mutate($schedules, $prev_average_best_fit_score, $next_average_best_fit_score);
	
	# Mutate every 500 generations to prevent plateauing and to give chance for new (probably better) mutation. Comment this to disable
	$schedules = mutate_to_NA($schedules, \%s_pref, \%p_pref, 0) if $i != 0;

	$schedules = calculate_fitness($schedules);
	($schedules, $prev_average_best_fit_score) = sort_schedule($schedules);
	%schedules = %{$schedules};

	$schedules = fitnessfunc::conflict_resolve($schedules, \%p_sched) if $i % 10 == 0 and $i != 0;
	if ($i == $generation) {
		$schedules = mutate_to_NA($schedules, \%s_pref, \%p_pref, -1);
	}

	# Print best fit schedule so user can assess it
	print_current_schedule_debug(\%schedules) if $opt_v; # Print #1 schedule on terminal for fast debugging
	print_schedule($schedules);
	printf "Generation %d Score: $buffer_score\n", abs($i) if abs($i) == 1 and $opt_v;
	printf "Generation %d Score: $buffer_score (difference $addition from previous generation)\n", abs($i) if abs($i) > 1 and $opt_v;
}
my $best_output  = $dir . "best_schedule.txt";
my $score_graph  = $dir . "Score.pdf";
print "Best schedule: $best_output\n";
print "Score graph: $score_graph\n";

#########################################
#					#
#		SUBROUTINES		#
#					#
#########################################

sub calculate_fitness {
	my ($schedules) = @_;
	my %schedules = %{$schedules};

	my $highest_fitness_score = -999999;
	# Iterate through each schedule and count final fitness score
	foreach my $number (sort keys %schedules) {

        	# Get one schedule hash from the %schedules
		my %schedule = %{$schedules{$number}};

        	# Each genome (schedule) has initial score of 9000
		my $fitness_score;
        
		# 1. Fitness function conflict test #
        	$fitness_score = fitnessfunc::conflict_test(\%schedule);
		
		# 2. Fitness function professor schedule
		$fitness_score = fitnessfunc::prof_schedule_score(\%schedule, $fitness_score, \%p_sched);
		
		# 3. Fitness function based on professors' preference
		$fitness_score = fitnessfunc::prof_preference_score(\%schedule, $fitness_score, \%p_pref);
	
		# 4. Fitness function based on students' preference
		$fitness_score = fitnessfunc::stud_preference_score(\%schedule, $fitness_score, \%s_pref);
		
		# 5. Fitness function based on distance
		$fitness_score = fitnessfunc::get_distance_score(\%schedule, $fitness_score, \%dmat, \%p_table);
	
	        # 6. Record final fitness score to the schedules hash
	        $schedules{$number}{score} = $fitness_score;
      	}
	return(\%schedules);
}

sub sort_schedule {
	my ($schedules) = @_;
	my %schedules = %{$schedules};
	my %sorted;

	my $count = 0;
	my $average_best_fit_score = 0;
	foreach my $number (sort {$schedules{$b}{score} <=> $schedules{$a}{score}} keys %schedules) {
		$average_best_fit_score += $schedules{$number}{score} / ($selection_threshold * $pop_size) if $count < ($selection_threshold*$pop_size);
		$sorted{$count} = $schedules{$number};
		$count++;
		last if $count >= $pop_size;
	}
	return(\%sorted, $average_best_fit_score);
}

sub check_input_correctness {
	my ($directory, $generation, $pop_size, $selection_threshold) = @_;
	die "
usage: $0 [-v turn on messages] -d <directory of input> -g <generation> -p <pop size> -s <selection>\n
-g: Number of Generation (positive integer) [use 0 to run forever]
-p: Population Size (positive integer)
-s: Selection Threshold (positive float between 0 and 1) - Fraction of population to be kept 
    E.g. keep top 10% of population: -s 0.1

" unless defined($directory) and defined($generation) and defined($pop_size) and defined($selection_threshold);
	die "Directory does not exist!\n" 			     if not -d $directory;
	die "Population size has to be integer more than 0!\n"	     if $pop_size   !~ /^\d+$/ or $pop_size < 1;
	die "Generation has to be integer more than or eq as 0!\n"   if $generation !~ /^\d+$/ or $generation < 0;
	die "Top score has to be floating point between 0 to 1\n"    if $selection_threshold !~ /^0\.\d+$/ or $selection_threshold <= 0 or $selection_threshold >= 1;
}

sub process_data_files {
	my ($dir) = @_;

	# Professor Schedule Table Parsing
	
=head2 1. Professor Schedule Table: Schedule of availability of each professor

Table format is:

prof_name	location	slot(6)

where slot 0 is unavailable, 1 is available

=cut
	
	my $p_sched = "$dir\/professor_schedule_final.txt";
	open (my $p_sched_in, "<", $p_sched) or die "Cannot read from $p_sched: $!\n";
	my %p_sched; # prof schedule
	my %p_loc; # location for function 5 distance matrix
	while (my $line = <$p_sched_in>) {
		chomp($line);
		next if $line =~ /\#/;
		my ($name, $location, @slot) = split("\t", $line);
		for (my $j = 0; $j < @slot; $j++) {
			$p_sched{$name}{$j} = $slot[$j];
			$p_loc{$name} = $location;
		}
	}
	
	# Professor Info Table Parsing
	
=head2 2. Professor Info Table: Info of each professor's location

Table format is:
	
prof_name	place
	
where place correspond to distance matrix location data
	
=cut
	
	my $p_table = "$dir\/professor_table_final.txt";
	my %p_table;
	open (my $p_table_in, "<", $p_table) or die "Cannot read from $p_table: $!\n";
	while (my $line = <$p_table_in>) {
		next if $line =~ /\#/;
		chomp($line);
		my @arr = split("\t", $line);
		$p_table{$arr[0]}{name} = $arr[1];
		$p_table{$arr[0]}{place} = $arr[2];
	}
	
	# Professor Prefrence Table Parsing
	
=head2 3. Professor Preference Table: List of professor that want to meet with certain students
	
Table format is:
	
prof_name	students(>=0)
	
=cut
	
	my $p_pref = "$dir\/professor_preference_final.txt";
	my %p_pref;
	open (my $p_pref_in, "<", $p_pref) or die "Cannot read from $p_pref\n";
	while (my $line = <$p_pref_in>) {
		next if $line =~ /\#/;
		chomp($line);
		my ($name, @arr) = split("\t", $line);
		@{$p_pref{$name}} = @arr;
	}
	close $p_pref_in;

	# Student Table Parser
=head2 4. Professor Info Table: Info of each professor's location

Table format is:
	
code	student_name	
		
=cut
	
	my $s_table = "$dir\/student_table_final.txt";
	my %s_table;
	open (my $s_table_in, "<", $s_table) or die "Cannot read from $s_table: $!\n";
	while (my $line = <$s_table_in>) {
		next if $line =~ /\#/;
		chomp($line);
		my @arr = split("\t", $line);
		$s_table{$arr[0]}{name} = $arr[1];
	}
	
	# Student Preference Table Parser
	
=head2 5. Student Preference Table: List of students that want to meet with certain professors
	
Table format is:
	
student_name	prof1_score1(>=0)
	
score for each prof is between
	
=cut
	
	my $s_pref = "$dir\/student_preference_final.txt";
	my %s_pref;
	open (my $s_pref_in, "<", "$s_pref") or die "Cannot read from $s_pref: $!\n";
	while (my $line = <$s_pref_in>) {
		chomp($line);
		my ($name, @prof) = split("\t", $line);
		for (my $j = 0; $j < @prof; $j++) {
			my $prof = $prof[$j];
			my $p_score = (@prof - $j - 1) > 10 ? 10 : @prof - $j - 1;
			$s_pref{$name}{$prof} = $p_score;
			}
	}
	close $s_pref_in;
	
	#Distance Matrix Parser
	
=head2 6. Distance Matrix: List of distances between two buildings
	
Format is:
	
	building0	building1	etc
	
building0	0	0.2	etc
	
building1	0.2	0	etc
	
This is converted into time in minutes

=cut
	
	my $dmat = "$bin_dir\/GPSmatrixgen/distcoords.txt";
	my %dmat;
	my @pos;
	open (my $dmat_in, "<", $dmat) or die "Cannot read from $dmat: $!\n";
	my $linecount;
	while (my $line = <$dmat_in>) {
		$linecount++;
		chomp($line);
		my @arr = split("\t", $line);
		if ($linecount == 1) {
			for (my $j = 1; $j < @arr; $j++) {
				$pos[$j] = $arr[$j];
			}
		}
		else {
			for (my $j =  1; $j < @arr; $j++) {
				my $time = 0;
				my $speed = 3;
				if ($arr[$j] > 0.8) {
					$speed = 45;
					$time += 5/60;
				}
				$dmat{$arr[0]}{$pos[$j]} = ($arr[$j]/$speed + $time)*60;
			}
		}
	}
	close $dmat_in;
	
	return(\%p_sched, \%p_table, \%p_pref, \%s_table, \%s_pref, \%dmat, \%p_loc);
}

sub generate_random_schedules {

	#Initialize hashes required for multilayer hash storage of random table generator
	my %schedules;          # contains all randomly generated hashes
	my $counts = 0;

	# Total professor schedule
	my $total_professor_slot = 0;
	
	# Seed
	while ($counts != $pop_size)   {

		foreach my $prof (keys %p_sched) {
			$total_professor_slot = (keys %{$p_sched{$prof}}) if $total_professor_slot < (keys %{$p_sched{$prof}});

			my %used;
			foreach my $slot (keys %{$p_sched{$prof}}) {
				my $avail = $p_sched{$prof}{$slot};
				# 1. slot 0 is NA
				$schedules{$counts}{data}{$prof}{$slot} = "NA" if $avail == 0;
				# 2. Professor will meet their desired student in non-NA place
				next if not defined(@{$p_pref{$prof}}) or @{$p_pref{$prof}} == 0;
				while (1) {
					my $random_pref = int(rand((@{$p_pref{$prof}})));
					if (@{$p_pref{$prof}} != 0 and not grep(/^$p_pref{$prof}[$random_pref]$/i, @{$used{$prof}})) {
						$schedules{$counts}{data}{$prof}{$slot} = $p_pref{$prof}[$random_pref];
						push(@{$used{$prof}}, $p_pref{$prof}[$random_pref]);
						last;
					}
					last if @{$used{$prof}} == @{$p_pref{$prof}};

				}
			}
		}

		# Seed so that student meet their professor of choice
		foreach my $student (sort keys %s_pref) {
			foreach my $prof (sort keys %{$s_pref{$student}}) {
				next if not defined($p_pref{$prof});
				my $slot = int(rand($total_professor_slot));
				$schedules{$counts}{data}{$prof}{$slot} = $student if not defined($schedules{$counts}{data}{$prof}{$slot});
			}
		}


	        foreach my $prof (@gen_prof) {
			
	                my @RandomStudents = random_students(\@gen_stud, $total_professor_slot);
	                for (my $i = 0; $i < @RandomStudents; $i++) {
	                        my $student = $RandomStudents[$i];
	                        $schedules{$counts}{data}{$prof}{$i} = $student if not defined($schedules{$counts}{data}{$prof}{$i});
	                }
        	}
		$counts++;
	}
	return(\%schedules);
}

sub random_students{
        my ($students, $total_professor_slot) = @_;
	my @students = @{$students};
        my @random_students;
        while ($total_professor_slot != 0) {
                my $random = int(rand(@gen_stud));
                my $individual = $students[$random];
                push (@random_students, "$individual");
                $total_professor_slot--;
        }
        return @random_students;
}

sub select_and_breed {
	my ($schedules, $total_children) = @_;
	my %schedules = %{$schedules};
	my %sorted;

	# Define top scorer
	my $topscorers  = int ($selection_threshold * $pop_size); 
	#$total_children = $pop_size - $topscorers if not defined($total_children);

	# Create new schedule
	my %newschedule = %schedules;

	#for (my $i = 0; $i < $topscorers; $i++) {
	#	$newschedule{$i} = $schedules{$i};
	#}

	#if ($total_children > $pop_size) {
	#	print "Because diff is zero, (we create 10*$pop_size ($total_children) now\n";
	#}
	for (my $i = $topscorers+1; $i < $pop_size; $i++) { 
		foreach my $prof (keys %{$schedules{$i}{data}}) { 
			foreach my $time (keys %{$schedules{$i}{data}{$prof}}) { 
				my $random = int (rand(1) * $topscorers);
				$newschedule{$i}{data}{$prof}{$time} = $schedules{$random}{data}{$prof}{$time};
			}
		}
	}

	return(\%newschedule);
}

sub mutate {
	my ($schedule, $children_score, $parents_score) = @_;
	my %schedule = %{$schedule};
	my $count = (keys %schedule);

	my $mutatenum = 0.02;

	#my $totsch = 0.85*(keys %schedule);
	#my $diff_fitness_score = abs($children_score - $parents_score);

	#if ($diff_fitness_score <= 0.0000001) {
	#	print "diff = $diff_fitness_score\n";
	#	($schedule) = select_and_breed(\%schedule, 10*$pop_size);
	#	%schedule = %{$schedule};
	#	$mutatenum =  (0.01-$diff_fitness_score)/0.01 * 0.15;
	#
	#}

	foreach my $number (sort {$a <=> $b} keys %schedule) {
		next if $number < $selection_threshold/2 * (keys %schedule);
		foreach my $prof (keys %{$schedule{$number}{data}}) {
			foreach my $slot (sort {$a <=> $b} keys %{$schedule{$number}{data}{$prof}}) {
				my $mutate = rand();
				if ($mutate < $mutatenum) {
					my $studmutate = $gen_stud[int(rand(@gen_stud))];
					$schedule{$number}{data}{$prof}{$slot} = $studmutate;
				}

				# Try to seed student with their professor of preference
				# So far, the best is if it happens all the time 
				if ($mutate < 0.5) {
					my $current_stud = $schedule{$number}{data}{$prof}{$slot};
					next if defined($s_pref{$current_stud}{$prof}) and $s_pref{$current_stud}{$prof} !~ /^$/;
					foreach my $student (@gen_stud) {
						next if $student eq "NA";
						my $next = 0;
						if (defined($s_pref{$student}{$prof})) {
							foreach my $slot2 (keys %{$schedule{$number}{data}{$prof}}) {
								next if $slot eq $slot2;
								if ($schedule{$number}{data}{$prof}{$slot2} eq $student) {
									$next = 1;
								last;
								}
							}
						}
						else {
							next;
						}
						next if $next == 1;
						if (defined($s_pref{$student}{$prof})) {
							$schedule{$number}{data}{$prof}{$slot} = $student;
						}
					}
				}
			}
		}
	}

	return(\%schedule);
}

sub mutate_to_NA {
	my ($schedule, $s_pref, $p_pref, $count) = @_;
	my %schedule = %{$schedule};
	my %s_pref = %{$s_pref};
	my %p_pref = %{$p_pref};
	my $max_slot = 0;

	foreach my $number (keys %schedule) {
		next if $number < $selection_threshold * (keys %schedule);
		foreach my $prof (keys %{$schedule{$number}{data}}) {
			foreach my $slot (keys %{$schedule{$number}{data}{$prof}}) {
				$max_slot = $slot if $max_slot < $slot;
				my $student = $schedule{$number}{data}{$prof}{$slot};
				next if $student eq "NA";

				if (@{$p_pref{$prof}} != 0 and rand() < 0.005 and $p_sched{$prof}{$slot} != 0) {
					my $student2 = $p_pref{$prof}[int(rand(@{$p_pref{$prof}}))];
					my $check_student_exists = 0;
					foreach my $slot2 (keys %{$schedule{$number}{data}{$prof}}) {
						$check_student_exists = 1 if $student eq $student2;
					}
					$schedule{$number}{data}{$prof}{$slot} = $student2 if $check_student_exists == 0;
				}

			}
		}
	}
	foreach my $number (keys %schedule) {
		foreach my $prof (sort keys %{$schedule{$number}{data}}) {
			for (my $i = 0; $i <= $max_slot; $i++) {
				my $slot = $i;
				my $student = $schedule{$number}{data}{$prof}{$slot};
				next if $student eq "NA";
				undef $s_pref{$student}{$prof} if defined($s_pref{$student}{$prof}) and $s_pref{$student}{$prof} =~ /^$/;
				if ($count <= 0 and not defined($s_pref{$student}{$prof})) {
					#print "Mutated to NA: $student slot $slot prof $prof\n";
					$schedule{$number}{data}{$prof}{$slot} = "NA";# if rand(1) < 0.5 and $count != -1;
					$schedule{$number}{data}{$prof}{$slot} = "NA" if $count == -1;
				}
			}
		}
	}
	return(\%schedule);
}

sub print_current_schedule_debug {
	my ($schedule) = @_;
	my $max_slot = 0;
	my %schedule = %{$schedule};
	my %data;
	print "\nProfessor Schedule (Professor availability is on the right)";
	foreach my $number (sort {$schedule{$b}{score} <=> $schedule{$a}{score}} keys %schedule) {
		foreach my $prof (sort keys %{$schedule{$number}{data}}) {
			my $profname = defined($p_table{$prof}{name}) ? $p_table{$prof}{name} : "NA";
			print"$prof\t";
			foreach my $slot (sort {$a <=> $b} keys %{$schedule{$number}{data}{$prof}}) {
				$max_slot = $slot if $max_slot < $slot;
				my $stud = $schedule{$number}{data}{$prof}{$slot};
				$data{$stud}{$slot} = $prof if $stud ne "NA";
				print "$stud\t";
			}
			print "|";
			foreach my $slot (sort {$a <=> $b} keys %{$p_sched{$prof}}) {
				print "\t$p_sched{$prof}{$slot}";
			}
			print "\n";
		}
		last;
	}
	print "\nStudent Schedule (Student preference table is on the right)\n";
	for (my $i = 0; $i < @gen_stud; $i++) {
		my $stud = $gen_stud[$i];
		next if $stud eq "NA";
		print "$stud\t";
		for (my $i = 0; $i <= $max_slot; $i++) {
			my $slot = $i;
			$data{$stud}{$slot} = "NA" if not defined($data{$stud}{$slot});
			print "$data{$stud}{$slot}\t";
		}
		print "|";
		foreach my $prof (sort keys %{$s_pref{$stud}}) {
			print "\t$prof";
			
		}
		print "\n";
	}
}
sub print_schedule {
	my ($schedule) = @_;
	my %schedule = %{$schedule};
	my %stud_sched;
	my $highest_score = -9999999;
	my $max_slot = 0;

	open (my $out, ">", "$dir/best_schedule.txt") or die "Cannot write to $dir/best_schedule.txt: $!\n";
	foreach my $number (sort {$schedule{$b}{score} <=> $schedule{$a}{score}} keys %schedule) {
		$highest_score = $schedule{$number}{score};
		last;
	}
	$highest_score = int(2000000 + $highest_score)/10000;

	print $out "# Score: $highest_score\n";
	print $out "# Best Professor Schedule\n";
	foreach my $number (sort {$schedule{$b}{score} <=> $schedule{$a}{score}} keys %schedule) {
		for (my $i = 0; $i < @gen_prof; $i++) {
			my $prof = $gen_prof[$i];
			my $profname = fix_name($p_table{$prof}{name});
			print $out "$profname";
			foreach my $slot (sort {$a <=> $b} keys %{$schedule{$number}{data}{$prof}}) {
				$max_slot = $slot if $max_slot < $slot;
				my $stud = $schedule{$number}{data}{$prof}{$slot};
				my $studname = defined($s_table{$stud}{name}) ? $s_table{$stud}{name} : "NA";
				print $out "\t$studname";
				next if $stud eq "NA";
				$stud_sched{$stud}{$slot} = $prof;
			}
			print $out "\n";
		}
		last;
	}
	print $out "\n# Best Student Schedule\n";
	for (my $i = 0; $i < @gen_stud; $i++) {
		my $stud = $gen_stud[$i];
		next if $stud eq "NA";
		my $studname = $s_table{$stud}{name};
		print $out "$studname";
		for (my $j = 0; $j <= $max_slot; $j++) {
			my $prof = $stud_sched{$stud}{$j};
			$prof = "NA" if not defined($prof);
			my $profname = defined($p_table{$prof}{name}) ? $p_table{$prof}{name} : "NA";
			$profname = fix_name($profname);
			print $out "\t$profname";
		}
		print $out "\n";
	}
	print $out "\n# Location\n";
	for (my $i = 0; $i < @gen_stud; $i++) {
		my $stud = $gen_stud[$i];
		next if $stud eq "NA";
		my $studname = $s_table{$stud}{name};
		print $out "$studname";
		for (my $j = 0; $j <= $max_slot; $j++) {
			my $prof = $stud_sched{$stud}{$j};
			$prof = "NA" if not defined($prof);
			print $out "\tBREAK" and next if $prof eq "NA";
			my $loc = $p_loc{$prof};
			print $out "\t$loc";
		}
		print $out "\n";
	}
	print $out "\n";
}

sub fix_name {
	my ($name) = @_;
	my @name = split(" ", $name);
	my @fixname;
	for (my $i = 0; $i < @name; $i++) {
		my ($first, $rest) = $name[$i] =~ /^(.)(.+)$/;
		$first = uc($first);
		push(@fixname, "$first$rest");
	}
	$name = join(" ", @fixname);
	return($name);
}

# Plotting score. We skipped first 2 generations because their score will always be 0
sub plot_score {
	my (@score) = @_;

	my $Rscript = "pdf(\"$dir/Score.pdf\")";

	my $y_axis = "score = c(";
	for (my $i = 0; $i < @score; $i++) {
		my $line_ending = $i == @score - 1 ? ")" : ",";
		$y_axis .= "$score[$i]$line_ending";
	}
	my $x_axis = "xaxis = seq(1:length(score))";
	$Rscript .= "
	$y_axis
	$x_axis
	plot(xaxis,score,xlab=\"Generation\",ylab=\"Score\",type=\"n\",main=\"Score over Generation\")
	lines(xaxis,score,col=\"red\")
	points(xaxis,score,col=\"black\",pch=\".\")
	dev.off()
	";
	open (my $out, ">", "$dir/Score.R") or print "Failed to print out Generation x Score R script: $!\n";
	print $out "$Rscript\n";
	#system("R --no-save < $dir/Score.R") == 0 or die "Failed to run R script that plot Generation x Scores: $!\n";
	system("R --no-save < $dir/Score.R > /dev/null 2&>1 && sleep 0.01") == 0 or die "Failed to run R script that plot Generation x Scores: $!\n";

}
__END__

