#!/usr/bin/perl

use HTML::TreeBuilder;
use LWP::Simple;

my %dt;

format =
When/Where: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Arena: @<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $dt{'when_where'},                                                                         $dt{'arena'},
Perf Time:  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Slack: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $dt{'perfs/time'},                               $dt{'slack'},
Contact:    @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            $dt{'contact'}

.

my ( $mm, $yyyy ) = ( localtime(time) )[ 4, 5 ];
my @months   = qw(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC);
my $wpra_web = 'http://wpra.com/dtschedule%s.htm';

my @wpra_fields      = qw{when_where arena perf_time slack added eligibility ground_rules contact eoo ec};
my $max_field_length = 0;
foreach (@wpra_fields)
{
    $max_field_length = length($_) if ( $max_field_length < length($_) );
}

foreach my $_i ( 0 .. 3 )
{
    print $months[ ( $mm + $_i ) % scalar(@months) ], "\n";
    print '-' x length( $months[ ( $mm + $_i ) % scalar(@months) ] ), "\n";

    my $_url = sprintf( $wpra_web, $months[ ( $mm + $_i ) % scalar(@months) ] );
    if ( my $_content = get($_url) )
    {

        my ($_dt_schedule_month) = ( $_content =~ /\W(\w+)\W+Divisional\s+Tour\s+Schedule/ );
        my $_tree = HTML::TreeBuilder->new_from_content($_content);

        $_tree->delete_ignorable_whitespace();

        # delete a bunch of icky tags
        my @tags_to_delete = qw(o span font b i meta);
        my %tag_hash       = %{ $_tree->tagname_map() };
        foreach my $_tag ( @tag_hash{@tags_to_delete} )
        {
            $_->replace_with_content() foreach (@$_tag);
        }
        delete $tag_hash{$_} foreach (@tags_to_delete);

        # strip attributes that are not hrefs, no matter where they're found
        foreach my $_tag ( keys %tag_hash )
        {
            foreach my $_t ( @{ $tag_hash{$_tag} } )
            {
                foreach ( $_t->all_attr_names() )
                {
                    next if (/^_/);
                    next if (/^(?:href|src|class|title|id|alt)$/);
                    $_t->attr( $_ => undef );
                }
            }
        }

        # strip empty div tags, starting with the deepest nestings, moving backwards
        foreach my $_t ( $tag_hash{'div'} )
        {
            foreach ( reverse @$_t )
            {
                $_->replace_with_content() if ( $_->is_empty() );
            }
        }
        delete $tag_hash{'div'};

        foreach my $_p ( $_tree->find_by_tag_name('p') )
        {

            foreach my $_br ( $_p->look_down( '_tag' => 'br' ) )
            {
                $_br->replace_with("\n");
            }

            my @text = split( /[\n\r]+/, $_p->as_text() );

            %dt = ( 'when_where' => join( ' ', splice( @text, 0, 2 ) ) );
            next if ( $dt{'when_where'} !~ /\b(?:AZ|NM)\b/ );

            foreach (@text)
            {
                my ( $n, $v ) = split( /\s*:\s*/, $_, 2 );
                $dt{ lc($n) } = $v;
            }
            next if ( !$dt{'arena'} );

            # ( $dt{'arena'} )        = ( $_t =~ m{arena:(.+?)perfs/time:}i );
            # ( $dt{'perfs/time'} )    = ( $_t =~ m{perfs/time:(.+)\bslack:}i );
            # ( $dt{'slack'} )        = ( $_t =~ m{slack:(.+)\badded:}i );
            # ( $dt{'added'} )        = ( $_t =~ m{added:(.+)\beligibility:}i );
            # ( $dt{'eligibility'} )  = ( $_t =~ m{eligibility:(.+)\bground rules:}i );
            # ( $dt{'ground_rules'} ) = ( $_t =~ m{ground rules:(.+)\bcontact:}i );
            # ( $dt{'contact'} )      = ( $_t =~ m{contact:(.+)\beoo:}i );
            # ( $dt{'eoo'} )          = ( $_t =~ m{eoo:(.+)\bec:}i );
            # ( $dt{'ec'} )           = ( $_t =~ m{ec:(.+)$}i );

            foreach ( keys %dt )
            {
                $dt{$_} =~ s/^\s+//;
                $dt{$_} =~ s/\s+$//;
                next if ( $dt{$_} =~ /^$/ );

                $dt{$_} =~ s/\s\s+$/ /g;
            }

            write;
        }
    }
    print "\n";
}
