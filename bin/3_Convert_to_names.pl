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

####################################
# 3_Convert_to_names.pl		   #
# This script converts code names  #
# in result file into names	   #
####################################

use strict; use warnings;
use scheduler;

my ($schedule) = @ARGV;
die "usage: $0 schedule file\n" unless @ARGV;

my (%stud, %prof);
open (my $ptable_in, "<", "Data/professor_table_final.txt") or die "Cannot read from professor_table_final.txt: $!\n";
while (my $line = <$ptable_in>) {
	chomp($line);
	next if $line =~ /\#/;
	my ($code, $name, $room) = split("\t", $line);
	$prof{$code} = $name;
}
close $ptable_in;
open (my $stable_in, "<", "Data/student_table_final.txt") or die "Cannot read from student_table_final.txt: $!\n";
while (my $line = <$stable_in>) {
	chomp($line);
	next if $line =~ /\#/;
	my ($code, $name) = split("\t", $line);
	$stud{$code} = $name;
}
close $stable_in;

open (my $in, "<", $schedule) or die "Cannot read from $schedule: $!\n";
open (my $out, ">", "$schedule.converted") or die "Cannot write to $schedule.converted: $!\n";
while (my $line = <$in>) {
	chomp($line);
	if ($line =~ /^(p\d+)/ or $line =~ /^(s\d+)/) {
		$line =~ s/ +/\t/ig;
		my ($prof, @other) = split("\t", $line);
		print $out "$prof{$prof}\t" if $prof =~ /p\d+/;
		print $out "$stud{$prof}\t" if $prof =~ /s\d+/;
		for (my $i = 0; $i < @other; $i++) {
			my $names = $other[$i];
			if ($names =~ /(s\d+)/i or $names =~ /(p\d+)/) {
				if ($names =~ /p\d+\_\d+/) {
					my ($others, $score) = $names =~ /^(p\d+)\_(\d+)$/;
					print $out "$prof{$others}_$score\t";
				}
				else {
					print $out "$stud{$names}\t" if $names =~ /(s\d+)/;
					print $out "$prof{$names}\t" if $names =~ /(p\d+)/;
					print "$prof $names\t$prof{$names}\n" if $names =~ /(p\d+)/ and $names eq "p26";
				}
			}
			else {
				print $out "$names\t";
			}
		}
		print $out "\n";
	}
	else {
		print $out "$line\n";
	}
}


print "Output file: $schedule.converted\n";
close $in;
close $out
