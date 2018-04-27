# Copyright (C) 2018 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package OpenQA::Parser::Format::TAP;
# Translates to TAP -> openQA internal
use Mojo::Base 'OpenQA::Parser::Format::Base';
use Carp qw(croak confess);
use OpenQA::Parser::Result::OpenQA;
use TAP::Parser;
use Data::Dumper;

has [qw(test steps)];

# Override to use specific OpenQA Result class.
sub _add_single_result { shift->generated_tests_results->add(OpenQA::Parser::Result::OpenQA->new(@_)) }

sub _add_result {
    my $self = shift;
    my %opts = ref $_[0] eq 'HASH' ? %{$_[0]} : @_;
    return $self->_add_single_result(@_) unless $self->include_results && $opts{name};

    my $name = $opts{name};
    my $tests = $self->generated_tests->search('name', qr/$name/);

    if ($tests->size == 1) {
        $self->_add_single_result(@_, test => $tests->first);
    }
    else {
        $self->_add_single_result(@_);
    }

    return $self->generated_tests_results;
}

sub parse {
    my ($self, $TAP) = @_;
    confess "No TAP given/loaded" unless $TAP;
    my $tap = TAP::Parser->new({ tap => $TAP });
    confess "Failed ".$tap->parse_errors if $tap->parse_errors ;
    my $test =
        {
            flags    => {},
            category => "TAP",
            name     =>  'Extra test from TAP',
        };
    $self->steps(OpenQA::Parser::Results->new);
    my $details;
    my $m = 0;
    while (my $res = $tap->next) {
        my $result =  $res;
        # For the time being only load known types
        # Tests are supported and comments too
        # print Dumper($result);

        if( $result->raw =~  m/^(.*\.tap) \.{2}/g)  {
            $details = { result => 'failed' };
            # most cases, teh output of a prove run will contain
            # "/t/$filename.tap .." as name of the file
            # use this to get the filename
            $test->{name} =$1;
            $test->{name} =~ s/\//_/;
            $test->{result} = ($tap->failed)? 'failed' : 'passed';
            $self->test(OpenQA::Parser::Result->new($test));
            next;
        } else {
            confess "A valid TAP starts with filename.tap, and got: '@{[$result->raw]}'" unless $self->test;
        }

        # stick for now to only test results.
        next if $result->type eq 'plan'; # Skip plans for now
        next if $result->type ne 'test';

        my $t_filename = "TAP-@{[$test->{name}]}-$m.txt";
        $details = {
            text  => $t_filename,
            title => $result->raw,
            result => ($result->is_actual_ok)? 'passed' : 'fail',
        };

        # Ensure that text files are going to be written
        # With the content that is relevant
        $self->_add_output(
            {
                file    => $t_filename,
                content => $res->raw
            });
        #$result->{name} = $test->{name};
        my $data = {%$result, %$details};
        push @{$test->{steps}}, $details;
        $self->_add_result($data);
        ++$m;
    }
    $self->_add_test($self->test);
}

=encoding utf-8

=head1 NAME

OpenQA::Parser::Format::TAP - TAP file parser

=head1 SYNOPSIS

    use OpenQA::Parser::Format::TAP;

    my $parser = OpenQA::Parser::Format::TAP->new()->load('test.tap');

    # Alternative interface
    use OpenQA::Parser qw(parser p);

    my $parser = parser( TAP => 'test.tap' );

    my $result_collection = $parser->results();
    my $test_collection   = $parser->tests();
    my $output_collection = $parser->output();

    my $arrayref = $result_collection->to_array;

    $parser->results->remove(0);

    my $passed_results = $parser->results->search( result => qr/ok/ );
    my $size = $passed_results->size;


=head1 DESCRIPTION

OpenQA::Parser::Format::TAP is the parser for Test Anything Protocol format.
The parser is making use of the C<tests()>, C<results()> and C<output()> collections.

=head1 ATTRIBUTES

OpenQA::Parser::Format::TAP inherits all attributes from L<OpenQA::Parser::Format::Base>.

=head1 METHODS

OpenQA::Parser::Format::TAP inherits all methods from L<OpenQA::Parser::Format::Base>, it only overrides
C<parse()> to generate a simple tree of results.

=cut

!!42;
