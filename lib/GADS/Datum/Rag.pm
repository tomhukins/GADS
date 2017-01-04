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

package GADS::Datum::Rag;

use Data::Dumper;
use Log::Report;
use Moo;
use namespace::clean;

extends 'GADS::Datum::Code';

has set_value => (
    is      => 'rw',
    trigger => sub {
        my $self = shift;
        $self->_set_has_value(1);
    },
);

has value => (
    is       => 'rw',
    lazy     => 1,
    clearer  => 1,
    builder  => sub {
        my $self = shift;
        $self->_transform_value($self->init_value);
    },
);

has has_value => (
    is => 'rwp',
);

has layout => (
    is       => 'rw',
    required => 1,
);

has params_red => (
    is => 'lazy',
);

sub _build_params_red
{   my $self = shift;
    $self->_sub_param_values($self->column->params_red);
}

has params_amber => (
    is => 'lazy',
);

sub _build_params_amber
{   my $self = shift;
    $self->_sub_param_values($self->column->params_amber);
}

has params_green => (
    is => 'lazy',
);

sub _build_params_green
{   my $self = shift;
    $self->_sub_param_values($self->column->params_green);
}

sub _transform_value
{   my ($self, $original) = @_;

    my $column = $self->column;
    my $layout = $self->layout;

    if (exists $original->{value} && !$self->force_update)
    {
        return $original->{value};
    }
    elsif (!$self->column->green && !$self->column->amber && !$self->column->red)
    {
        return $self->_write_rag('a_grey');
    }
    else {
        # Used during tests to check that $original is being set correctly
        panic "Entering calculation code"
            if $ENV{GADS_PANIC_ON_ENTERING_CODE};

        my $ragvalue; my %error;
        if ( try { $column->eval('red', @{$self->params_red}) } )
        {
            $ragvalue = 'b_red';
        }
        elsif($@) {
            $error{code}   = $self->column->red;
            $error{text}   = $@->wasFatal->message->toString;
            $error{params} = $self->params_red;
        }
        if (!%error && !$ragvalue && try { $column->eval('amber', @{$self->params_amber}) } )
        {
            $ragvalue = 'c_amber';
        }
        elsif($@) {
            $error{code}   = $self->column->amber;
            $error{text}   = $@->wasFatal->message->toString;
            $error{params} = $self->params_amber;
        }
        if (!%error && !$ragvalue && try { $column->eval('green', @{$self->params_green}) } )
        {
            $ragvalue = 'd_green';
        }
        elsif($@) {
            $error{code}   = $self->column->green;
            $error{text}   = $@->wasFatal->message->toString;
            $error{params} = $self->params_green;
        }
        if (%error) {
            # An exception occurred evaluating the code
            $ragvalue = 'e_purple';
            warning __x"Failed to eval rag: {error} (code: {code}, params: {params})",
                error => $error{text}, code => $error{code}, params => Dumper(@{$error{params}});
        }
        $ragvalue ||= 'a_grey';
        return $self->_write_rag($ragvalue);
    }
}

sub _write_rag
{   my $self = shift;
    $self->write_cache('ragval', @_);
}

# XXX Why is this needed? Error when creating new record otherwise
sub as_integer
{   my $self = shift;
    !$self->value
        ? 0
        : $self->value eq 'a_grey'
        ? 1
        : $self->value eq 'b_red'
        ? 2
        : $self->value eq 'c_amber'
        ? 3
        : $self->value eq 'd_green'
        ? 4
        : $self->value eq 'e_purple'
        ? -1
        : -2;
}

sub as_string
{   my $self = shift;
    $self->value // "";
}

sub equal
{   my ($self, $a, $b) = @_;
    $a eq $b;
}

1;

