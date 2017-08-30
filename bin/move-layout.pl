#!/usr/bin/perl

=pod
GADS - Globally Accessible Data Store
Copyright (C) 2017 Ctrl O Ltd

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

use FindBin;
use lib "$FindBin::Bin/../lib";

use Dancer2;
use Dancer2::Plugin::DBIC;
use GADS::Config;
use Getopt::Long qw(:config pass_through);
use YAML::XS qw/LoadFile DumpFile/;

GADS::Config->instance(
    config => config,
);

my ($instance_id, $site_id, $load_file, $dump_file);
GetOptions (
    'instance-id=s' => \$instance_id,
    'site-id=s'     => \$site_id,
    'load-file=s'   => \$load_file,
    'dump-file=s'   => \$dump_file,
) or exit;

$instance_id or die "Need --instance-id";
$site_id or die "Need --site-id";
$load_file || $dump_file or die "Need either --load-file or --dump-file";

schema->site_id($site_id);

my $layout = GADS::Layout->new(
    user_permission_override => 1,
    user                     => undef,
    instance_id              => $instance_id,
    config                   => config,
    schema                   => schema,
);

if ($load_file)
{
    my %loaded;
    my $array = LoadFile $load_file;
    $loaded{$_->{id}} = $_ foreach @$array;

    foreach my $field ($layout->all)
    {
        if (my $new = $loaded{$field->id})
        {
            $field->name          ($new->{name});
            $field->name_short    ($new->{name_short});
            $field->type          ($new->{type});
            $field->optional      ($new->{optional});
            $field->remember      ($new->{remember});
            $field->isunique      ($new->{isunique});
            $field->textbox       ($new->{textbox})
                if $field->can('textbox');
            $field->typeahead     ($new->{typeahead})
                if $field->can('typeahead');
            $field->force_regex   ($new->{force_regex} || '')
                if $field->can('force_regex');
            $field->position      ($new->{position});
            $field->ordering      ($new->{ordering});
            $field->end_node_only ($new->{end_node_only})
                if $field->can('end_node_only');
            $field->multivalue    ($new->{multivalue});
            $field->description   ($new->{description});
            $field->helptext      ($new->{helptext});
            $field->display_field ($new->{display_field});
            $field->display_regex ($new->{display_regex});
            $field->link_parent_id($new->{link_parent_id});
            $field->filter->as_json($new->{filter});
            $field->_set_options   ($new->{options});
            $field->enumvals       ($new->{enumvals})
                if $field->type eq 'enum';
            $field->curval_field_ids($new->{curval_field_ids})
                if $field->type eq 'curval';

            $field->write(no_cache_update => 1);
        }
        else {
            say STDERR "Field ".$field->name." (ID ".$field->id.") not in updated layout - needs manual deletion";
        }
    }
}
else {

    my @out;
    foreach my $field ($layout->all)
    {
        my $hash = {
            id             => $field->id,
            name           => $field->name,
            name_short     => $field->name_short,
            type           => $field->type,
            optional       => $field->optional,
            remember       => $field->remember,
            isunique       => $field->isunique,
            textbox        => $field->can('textbox') ? $field->textbox : 0,
            typeahead      => $field->can('typeahead') ? $field->typeahead : 0,
            force_regex    => $field->can('force_regex') ? $field->force_regex : '',
            position       => $field->position,
            ordering       => $field->ordering,
            end_node_only  => $field->can('end_node_only') ? $field->end_node_only : 0,
            multivalue     => $field->multivalue,
            description    => $field->description,
            helptext       => $field->helptext,
            display_field  => $field->display_field,
            display_regex  => $field->display_regex,
            link_parent_id => $field->link_parent_id,
            filter         => $field->filter->as_json,
            options        => $field->options,
        };
        $hash->{enumvals} = $field->enumvals if $field->type eq 'enum';
        $hash->{curval_field_ids} = $field->curval_field_ids if $field->type eq 'curval';
        push @out, $hash;
    }
    DumpFile $dump_file, [@out];
}

