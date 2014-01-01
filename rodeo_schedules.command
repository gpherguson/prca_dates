#!/usr/bin/perl -w

use strict;

use LWP::Simple;
use HTML::TreeBuilder;

my $start_link_format = 'http://sports.espn.go.com/prorodeo/news/story?page=g_calendar_%4dresults_%s';
my @month_names       = qw( January February March April May June July August September October November December);
my %months            = (
    'January'   => 'jan',
    'February'  => 'feb',
    'March'     => 'march',
    'April'     => 'april',
    'May'       => 'may',
    'June'      => 'june',
    'July'      => 'july',
    'August'    => 'aug',
    'September' => 'sept',
    'October'   => 'oct',
    'November'  => 'nov',
    'December'  => 'dec',
);

my $months_to_get = 5;
my $timeout       = 180;

#      0     1     2      3      4     5      6      7      8
# my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
my ( $mon, $year ) = ( localtime(time) )[ 4, 5 ];

foreach my $i ( 0 .. $months_to_get - 1 )
{
    my $month = $month_names[ ( $mon + $i ) % 12 ];

    my $p_len;
    printf "\nScanning %s%n\n", $month_names[ ( $mon + $i ) % 12 ], $p_len;
    print '-' x $p_len, "\n";

    my $start_link =
      sprintf( $start_link_format, 1900 + ( ( ( ( $mon + $i ) % 12 ) < $mon ) ? $year + 1 : $year ), $months{$month} );

    if ( my $html = get($start_link) )
    {
        my $tree = HTML::TreeBuilder->new_from_content($html);
        $tree->delete_ignorable_whitespace();

        foreach my $tr (
            $tree->look_down(
                '_tag'  => 'tr',
                'class' => qr{rowMOD[01]}
            )
          )
        {

            # ...and all the cells.
            my @rodeo_info = ();
            foreach ( $tr->look_down( '_tag' => 'td' ) )
            {
                push @rodeo_info, $_->{'_content'}[0] || '';
            }

            # skip non-Turquoise Circuit rodeos
            next if ( $rodeo_info[4] !~ /(?:AZ|NM)/ );

            foreach (@rodeo_info)
            {
                s/^\s+//;
                next if /^$/;

                s/\s+$//;
                s/\s\s+/ /g;
            }

            # reformat the dates
            foreach ( 0, 1 )
            {
                $rodeo_info[$_] = sprintf( '%02d/%02d/%4d', split( '/', $rodeo_info[$_] ) );
            }

            # extract the href from the link if there was one
            push @rodeo_info, ( pop @rodeo_info )->{'href'} if ( ref $rodeo_info[-1] );

            # and spit it out.
            print join( ', ', @rodeo_info ), "\n";
        }
    }
}

print "\n\n";

