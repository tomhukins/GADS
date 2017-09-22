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

package GADS::Datum::Curval;

use Moo;

extends 'GADS::Datum::Curcommon';

sub _transform_value
{   my ($self, $v) = @_;
    my $value = $v->{value};
    my ($record, $id);

    if (ref $value eq 'GADS::Record')
    {
        $record = $value;
        $id = $value->current_id;
    }
    elsif (ref $value)
    {
        $record = GADS::Record->new(
            schema               => $self->column->schema,
            layout               => $self->column->layout_parent,
            user                 => undef,
            record               => $value->{record_single},
            linked_id            => $value->{linked_id},
            parent_id            => $value->{parent_id},
            columns_retrieved_do => $self->column->curval_fields_retrieve,
        );
        $id = $value->{record_single}->{current_id};
    }
    else {
        $id = $value if !ref $value && defined $value; # Just ID
    }
    ($record, $id);
}

1;
