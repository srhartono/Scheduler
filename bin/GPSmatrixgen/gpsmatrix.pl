#!/usr/bin/perl
use strict; use warnings;
use Math::Trig; 

# gpsmatrix.pl by Linda Su 
# Reads in text file of tab-separated GPS coordinates (name, lon, lat). 
# Calculates distance between two GPS coordinates via Haversine formula. 

my ($input) = @ARGV;
die "usage: $0 <GPS coordinate (tsv format of name, longitude, latitude)>\n" unless @ARGV;
open (IN, "<$input") or die "gps coordinates file not found"; 

my %BUILDINGS; 

# read IN and store gps coordinates and buildings
while (<IN>) {
	my (@line) = split("\t", $_);
	$BUILDINGS{$line[0]}{lon} = $line[1]; 
	$BUILDINGS{$line[0]}{lat} = $line[2]; 
}
close IN; 

# print OUT Haversine Distance matrix between buildings
open (OUT, ">distcoords.txt"); 

# my %DISTANCECOORD; 
my $earth_radius = 3963.1676; # in miles

print OUT "\t", join ("\t", keys %BUILDINGS), "\n"; 

foreach my $bld1 (keys %BUILDINGS) { 
	print OUT "$bld1\t";
	foreach my $bld2 (keys %BUILDINGS) { 
	
	## inspired from http://www.perlmonks.org/?node_id=150054
	my $lat_1 = $BUILDINGS{$bld1}{lat};  
	my $lon_1 = $BUILDINGS{$bld1}{lon};
	my $lat_2 = $BUILDINGS{$bld2}{lat};
	my $lon_2 = $BUILDINGS{$bld2}{lon};
	my $delta_lat = deg2rad($lat_2) - deg2rad($lat_1);
	my $delta_lon = deg2rad($lon_2) - deg2rad($lon_1);

	my $a        = sin($delta_lat/2)**2	+ cos(deg2rad($lat_1)) 
				   * cos(deg2rad($lat_2)) * sin($delta_lon/2)**2;
	my $c        = 2 * (asin(sqrt($a)));
	my $distance = $earth_radius * $c;
	
	# $DISTANCECOORD{$bld1}{$bld2} = $distance; 		# stores distance coords (in case we need for something)
	my $score    = $distance; 
	
	# NOT SURE IF KEEPING: SCORING MATRIX - should determine what determines "driving" vs "walking" 
	# if ($distance >= 3) { $score = $distance / 45.00; } # assumes driving speed of 45 mph
	# else { $score = $distance / 3.00; }		# assumes walking speed = 3 mph
	printf OUT "%.4f\t", $score;
	}
	print OUT "\n";
}

close OUT; 
