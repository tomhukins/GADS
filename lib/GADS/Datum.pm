=pod
GADS - Globally Accessible Data Store
Copyright (C) 2014 Ctrl O Ltd

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
=cut

package GADS::Datum;

use HTML::Entities;
use Log::Report 'linkspace';
use Moo;
use MooX::Types::MooseLike::Base qw(:all);
use namespace::clean;

with 'GADS::Role::Presentation::Datum';

use overload 'bool' => sub { 1 }, '""'  => 'as_string', '0+' => 'as_integer', fallback => 1;

sub set_value
{   my ($self, $value, %options) = @_;
    error __"Cannot set this value as it is a parent value"
        if !$options{is_parent_value} && !$self->column->can_child && $self->record && $self->record->parent_id;
    $self->clear_for_code;
}

has record => (
    is       => 'ro',
    weak_ref => 1,
);

has record_id => (
    is => 'rw',
);

has current_id => (
    is => 'rw',
);

has column => (
    is => 'rw',
);

has changed => (
    is      => 'rw',
    isa     => Bool,
    default => 0,
);

has child_unique => (
    is      => 'rw',
    isa     => Bool,
    coerce  => sub { $_[0] ? 1 : 0 },
    default => 0,
    trigger => sub {
        my ($self, $value) = @_;
        $self->changed(1)
            if $self->_has_child_unique_old && $value != $self->_child_unique_old;
        $self->_child_unique_old($value);
    },
);

# Used to detect changes of child_unique
has _child_unique_old => (
    is        => 'rw',
    isa       => Bool,
    lazy      => 1,
    default   => 0,
    predicate => 1,
);

has blank => (
    is      => 'rw',
    isa     => Bool,
    lazy    => 1,
    builder => 1,
    clearer => 1,
    coerce  => sub { $_[0] ? 1 : 0 },
);

# Used to seed the value from the database
has init_value => (
    is        => 'ro',
    clearer   => 1,
    predicate => 1,
);

has init_no_value => (
    is  => 'rw',
    isa => Bool,
);

has oldvalue => (
    is => 'rw',
);

has has_value => (
    is => 'rw',
);

sub values
{   my $self = shift;
    panic "values() is now deprecated";
    my @values = ref $self->value eq 'ARRAY' ? @{$self->value} : ($self->value);
    # If a normal array is used (not array ref) then TT does not iterate over
    # the values properly if the only value is a "0"
    [@values];
}

# That value that will be used in an edit form to test the display of a
# display_field dependent field
sub value_regex_test
{   shift->text_all;
}

# Whether this value is going to require approval. Used to know when to use the
# oldvalue as the correct current value
has is_awaiting_approval => (
    is      => 'rw',
    isa     => Bool,
    default => 0,
);

sub text_all
{   my $self = shift;
    [$self->as_string];
}

sub html
{   my $self = shift;
    encode_entities $self->as_string;
}

sub html_form
{   my $self = shift;
    [ defined $self->value ? $self->value : '' ];
}

# The values needed to pass to the set_values function of a datum. Normally the
# same as the HTML fields, but overridden where necessary
sub set_values { shift->html_form }

# The value to search for unique values
sub search_values_unique
{   shift->html_form;
}

# Overridden where applicable
sub html_withlinks { $_[0]->html }

# Not lazy, otherwise changes in display_field will not update this
sub dependent_not_shown
{   my $self = shift;

    my @filters = @{$self->column->display_fields->filters}
        or return 0;

    my $display_condition = $self->column->display_condition;

    my $shown = 0;

    foreach my $filter (@{$self->column->display_fields->filters})
    {
        my $display_field_id = $filter->{column_id};
        my $display_regex = $filter->{value};

        if (!$self->record->fields->{$display_field_id})
        {
            $shown = 1;
            next;
        }

        my $matchtype = $filter->{operator};
        $display_regex = '^'.$display_regex.'$'
            if $matchtype =~ /equal/;
        my $values = $self->record->fields->{$display_field_id}->value_regex_test;
        my $this_not_shown = $matchtype =~ /not/ ? 0 : 1;
        $values = [''] if !@$values;
        foreach my $value (@$values)
        {
            if ($matchtype =~ /not/) {
                $this_not_shown = 1 if $value =~ /$display_regex/;
            } else {
                $this_not_shown = 0 if $value =~ /$display_regex/;
            }
        }

        $shown = 1 if !$this_not_shown;

        if ($display_condition)
        {
            if ($display_condition eq 'OR')
            {
                last if $shown;
            }
            else {
                $shown = 0 if $this_not_shown;
                last if !$shown;
            }
        }
    }

    return !$shown;
}

sub clone
{   my ($self, @extra) = @_;
    # This will be called from a child class, in which case @extra can specify
    # additional attributes specific to that class
    ref($self)->new(
        record         => $self->record,
        column         => $self->column,
        record_id      => $self->record_id,
        current_id     => $self->current_id,
        blank          => $self->blank,
        @extra
    );
}

has for_code => (
    is      => 'lazy',
    clearer => 1,
);

sub _build_for_code
{   my $self = shift;
    $self->as_string; # Default
}

sub _date_for_code
{   my ($self, $value) = @_;
    $value or return undef;
    +{
        year   => $value->year,
        month  => $value->month,
        day    => $value->day,
        hour   => $value->hour,
        minute => $value->minute,
        second => $value->second,
        epoch  => $value->epoch,
    };
}

1;

