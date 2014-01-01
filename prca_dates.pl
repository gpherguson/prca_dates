#!/usr/bin/perl

use warnings;
use strict;

use WWW::Mechanize;

my $URL       = 'http://prorodeo.com/calendar.aspx';
my $SITE_NAME = 'Turquoise Circuit';

my $TABLE_START = q{<table .+ id="ctl00_ContentPlaceHolder1_rptListing">};
my $TABLE_END   = q{</table>};

my @HTML_FILENAMES = map { "$_.html" } qw{rodeo_schedule rodeos_by_city rodeos_by_name};
my @COLUMN_NAMES = ( 'Rodeo name', 'City', 'State', 'Start Date', 'End Date', 'Website' );

my $mech   = WWW::Mechanize->new;
my %rodeos = ();

if ( ( my $resp = $mech->get($URL) )->is_success )
{

    if ( my $html = $resp->decoded_content )
    {

        # The PRCA still has screwed up HTML. The text from the top of the page to
        # the DOCTYPE tag needs to be stripped before parsing.
        if ( my ($table) = $html =~ m/$TABLE_START(.+)$TABLE_END/s )
        {

            $table =~ s{</table>.+\Z}{}s;

            # Reconstruct the page without all the garbage so it can be parsed.
            use HTML::TreeBuilder;

            if ( my $tb = HTML::TreeBuilder->new_from_content(qq{<html><body><table>$html</table></body></html>}) )
            {

                foreach my $_table ( $tb->look_down( '_tag' => 'table' ) )
                {

                    foreach my $_tr ( $_table->look_down( '_tag' => 'tr' ) )
                    {

                        my @td = ();
                        foreach my $_td ( $_tr->look_down( '_tag' => 'td' ) )
                        {
                            push @td, $_td->as_text;
                        }

                        next if ( ( !$td[2] ) || ( length( $td[2] ) > 2 ) );

                        foreach (@td)
                        {
                            s/^\s+//;
                            s/\s+$//;
                        }

                        $rodeos{"@td"} = [@td]
                          if ( ( $td[2] =~ /(?:AZ|NM)/i ) );
                    }
                }
            }

            my $page_title = "$SITE_NAME: Rodeo schedule";
            print "<html><head><title>$page_title</title></head><body>\n";

            if ( scalar( keys(%rodeos) ) )
            {

                print "<table>\n";

                print '<tr><th>', join( '</th><th>', @COLUMN_NAMES ), "</th></tr>\n";

                foreach my $_rodeo (
                    map { $rodeos{$_} }
                    sort sort_by_date keys(%rodeos)
                  )
                {
                    if ( my $_rodeo_url = $$_rodeo[-1] )
                    {
                        $$_rodeo[-1] = qq{<a href="http://$_rodeo_url">$_rodeo_url</a>};
                    }
                    print '<tr><td>', join( '</td><td>', @$_rodeo ), "</td></tr>\n";
                }
                print "</table>";

            }
            else
            {
                print '<p>No rodeos listed currently.</p>',
                  qq{<p>The <a href="$URL">PRCA schedule of rodeos</a> might have more information.</p>}, "\n";

            }
            print "</body></html>\n";
        }
    }
}

sub sort_by_date
{
    my ( $a_rodeo_name, $a_city, $a_state, $a_startdate, $a_enddate, undef ) = @{ $rodeos{$a} };
    my ( $b_rodeo_name, $b_city, $b_state, $b_startdate, $b_enddate, undef ) = @{ $rodeos{$b} };

    foreach ( $a_startdate, $a_enddate, $b_startdate, $b_enddate )
    {
        my ( $mm, $dd, $yy ) = split( '-', $_ );
        $_ = sprintf( "%04d%02d%02d", $yy, $mm, $dd );
    }

    $a_startdate <=> $b_startdate
      or lc("$a_city $a_state") cmp lc("$b_city $b_state")
      or lc($a_rodeo_name) cmp lc($b_rodeo_name);

}

sub sort_by_city
{
    my ( $a_rodeo_name, $a_city, $a_state, $a_startdate, $a_enddate, undef ) = @{ $rodeos{$a} };
    my ( $b_rodeo_name, $b_city, $b_state, $b_startdate, $b_enddate, undef ) = @{ $rodeos{$b} };

    foreach ( $a_startdate, $a_enddate, $b_startdate, $b_enddate )
    {
        my ( $mm, $dd, $yy ) = split( '-', $_ );
        $_ = sprintf( "%04d%02d%02d", $yy, $mm, $dd );
    }

    lc("$a_city $a_state") cmp lc("$b_city $b_state")
      or $a_startdate <=> $b_startdate
      or lc($a_rodeo_name) cmp lc($b_rodeo_name);

}

sub sort_by_rodeo
{
    my ( $a_rodeo_name, $a_city, $a_state, $a_startdate, $a_enddate, undef ) = @{ $rodeos{$a} };
    my ( $b_rodeo_name, $b_city, $b_state, $b_startdate, $b_enddate, undef ) = @{ $rodeos{$b} };

    foreach ( $a_startdate, $a_enddate, $b_startdate, $b_enddate )
    {
        my ( $mm, $dd, $yy ) = split( '-', $_ );
        $_ = sprintf( "%04d%02d%02d", $yy, $mm, $dd );
    }

    lc($a_rodeo_name) cmp lc($b_rodeo_name)
      or lc("$a_city $a_state") cmp lc("$b_city $b_state")
      or $a_startdate <=> $b_startdate;

}
