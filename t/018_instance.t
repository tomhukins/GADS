use Test::More; # tests => 1;
use strict;
use warnings;

use Log::Report;
use GADS::Instances;
use GADS::Users;

use lib 't/lib';
use Test::GADS::DataSheet;

my $sheet1 = Test::GADS::DataSheet->new(user_permission_override => 0);
$sheet1->create_records;
my $schema = $sheet1->schema;
my $layout1 = $sheet1->layout;

# Set up one normal user, one layout admin user
my $user_normal = $sheet1->user_normal1;
my $user_admin = $sheet1->user;

is($schema->resultset('Instance')->count, 1, "One instance created initially");

# Create second table, with no groups initially
my $group2 = $schema->resultset('Group')->create({ name => 'group2' });
my $layout2 = GADS::Layout->new(
    name       => 'Table2',
    user       => $user_admin,
    schema     => $schema,
    config     => $sheet1->config,
    set_groups => [],
)->write;

is($schema->resultset('Instance')->count, 2, "Second instance created");

# Tests for access dependent on field permissions
{
    # Admin user has access to both
    my $instances = GADS::Instances->new(schema => $schema, user => $user_admin );
    is(@{$instances->all}, 2, "Correct number of tables for admin");
    # Normal user has access to one
    $instances = GADS::Instances->new(schema => $schema, user => $user_normal );
    is(@{$instances->all}, 1, "Correct number of tables for normal user");
    # Check is_valid functionality
    ok($instances->is_valid(1), "Main instance is valid for normal user");
    ok(!$instances->is_valid(2), "Other instance not valid for normal user");
    # Add a field to second table that normal user has access to
    my $string1 = GADS::Column::String->new(
        schema   => $schema,
        user     => undef,
        layout   => $layout2,
    );
    $string1->type('string');
    $string1->name('string1');
    $string1->set_permissions({$sheet1->group->id, [qw/read/]});
    $string1->write;
    $instances = GADS::Instances->new(schema => $schema, user => $user_normal );
    is(@{$instances->all}, 2, "Correct number of tables for normal user after field added");
    $string1->delete;
}

# Delete table and replace with test table with all data etc
$layout2->purge;
is($schema->resultset('Instance')->count, 1, "Second instance deleted");

# Make sure same users is used from first sheet
my $sheet2 = Test::GADS::DataSheet->new(
    schema                   => $schema,
    instance_id              => 2,
    user_permission_override => 0,
    curval_offset            => 6,
    group                    => $sheet1->group,
    _users                   => $sheet1->_users,
);
$layout2 = $sheet2->layout;
$sheet2->create_records;

# Tests for table-level permissions. Add permission to table1, and check that
# not possible from table2
{
    foreach my $layout_from (qw/new instances/)
    {
        foreach my $test (qw/delete purge download layout message view_create create_child bulk_update link/)
        {
            foreach my $pass (1..4)
            {
                my $test_sheet;
                if ($pass == 1)
                {
                    # Test can't with first table
                    $test_sheet = $sheet1;
                }
                elsif ($pass == 2)
                {
                    # Test can't with second table
                    $test_sheet = $sheet2;
                }
                elsif ($pass == 3)
                {
                    # Test can with first table
                    $test_sheet = $sheet1;
                    # Add permission
                    my $perms = $test eq 'purge'
                        # Need both perms for deleting records without approval
                        ? [$sheet1->group->id.'_delete', $sheet1->group->id.'_purge']
                        : [$sheet1->group->id.'_'.$test];
                    $layout1->set_groups($perms);
                    $layout1->write;
                }
                else {
                    # Test can't with second table
                    $test_sheet = $sheet2;
                }
                my $layout;
                if ($layout_from eq 'new')
                {
                    $test_sheet->user_layout($user_normal);
                    $test_sheet->clear_layout;
                    $layout = $test_sheet->layout;
                }
                else {
                    $layout = GADS::Instances->new(schema => $schema, user => $user_normal)->layout($test_sheet->instance_id);
                }
                my $records = GADS::Records->new(
                    user   => $user_normal,
                    layout => $layout,
                    schema => $schema,
                );

                if ($test eq 'delete')
                {
                    my $record = $records->single;
                    try { $record->delete_current };

                    if ($pass == 3)
                    {
                        ok(!$@, "Able to delete record with correct permission for pass $pass");
                        # Add record back in
                        $schema->resultset('Current')->find($record->current_id)->update({ deleted => undef });
                    }
                    else {
                        like($@, qr/You do not have permission to delete records/, "Unable to delete record without required permission for pass $pass");
                    }
                }

                elsif ($test eq 'purge')
                {
                    my $record     = $records->single;
                    my $current_id = $record->current_id;
                    my $record_id  = $record->record_id;

                    # First check whether the user has access to view the deleted record.
                    # Temporary deletion
                    $schema->resultset('Current')->find($record->current_id)->update({ deleted => DateTime->now });
                    my $record_view = GADS::Record->new(
                        user   => $user_normal,
                        layout => $layout,
                        schema => $schema,
                    );
                    try { $record->find_deleted_currentid($current_id, $layout->instance_id) };
                    if ($pass == 3)
                    {
                        ok(!$@, "Accessed deleted record successfully");
                    }
                    else {
                        like($@, qr/You do not have access to this deleted record/, "Failed to access deleted record");
                    }
                    try { $record->find_deleted_recordid($record_id, $layout->instance_id) };
                    if ($pass == 3)
                    {
                        ok(!$@, "Accessed deleted historical record successfully");
                    }
                    else {
                        like($@, qr/You do not have access to this deleted record/, "Failed to access history of deleted record");
                    }
                    # Return to undeleted
                    $schema->resultset('Current')->find($current_id)->update({ deleted => undef });

                    try { $record->purge_current };

                    if ($pass == 3)
                    {
                        # Should have failed instead with record not being deleted
                        like($@, qr/Cannot purge record that is not already deleted/, "Cannot purge record not already deleted");
                        # Now delete and try again
                        $schema->resultset('Current')->find($current_id)->update({ deleted => DateTime->now });
                        try { $record->purge_current };
                        ok(!$@, "Able to purge record with correct permission for pass $pass");
                        # Add record back in
                        $test_sheet->create_records; # Adds 2 more records
                    }
                    else {
                        like($@, qr/You do not have permission to purge records/, "Unable to purge record without required permission for pass $pass");
                    }
                    # Try deleting a single version - there won't be one there, but
                    # should still bork, so safety check that this fails as well for
                    # every test where it shouldn't be possible
                    try { $record->purge };
                    unless ($pass == 3)
                    {
                        like($@, qr/You do not have permission to purge records/, "Unable to purge record version without required permission for pass $pass");
                    }
                }

                elsif ($test eq 'download')
                {
                    try { $records->csv_header };
                    my $failed = $@ =~ /You do not have permission to download data/;
                    try { $records->csv_line };
                    $failed = $failed && $@ =~ /You do not have permission to download data/;
                    if ($pass == 3)
                    {
                        ok(!$failed, "Able to download records with correct permission for pass $pass");
                    }
                    else {
                        ok($failed, "Unable to download records with correct permission for pass $pass");
                    }
                }

                elsif ($test eq 'layout')
                {
                    my ($col) = $layout->all(userinput => 1); # Get a random field
                    try { $col->write };
                    if ($pass == 3)
                    {
                        ok(!$@, "Able to write field with correct permission for pass $pass");
                    }
                    else {
                        like($@, qr/You do not have permission to manage field/, "Unable to write field with correct permission for pass $pass");
                    }
                }

                elsif ($test eq 'message')
                {
                    # All managed from controller at the moment
                }

                elsif ($test eq 'view_create')
                {
                    my $view = GADS::View->new(
                        instance_id => $layout->instance_id,
                        layout      => $layout,
                        schema      => $schema,
                        name        => 'Test',
                        global      => 0,
                        columns     => [],
                    );
                    try { $view->write };
                    if ($pass == 3)
                    {
                        ok(!$@, "Able to create view with correct permission for pass $pass");
                    }
                    else {
                        like($@, qr/does not have permission to create new views/, "Unable to create view with correct permission for pass $pass");
                    }
                }

                elsif ($test eq 'create_child')
                {
                    # Managed in controller at the moment
                }

                elsif ($test eq 'bulk_update')
                {
                    # Managed in controller at the moment
                }

                elsif ($test eq 'link')
                {
                    my $record = $records->single;
                    try { $record->write_linked_id($record->current_id) }; # Invalid link, but will work for test
                    if ($pass == 3)
                    {
                        ok(!$@, "Able to link record with correct permission for pass $pass");
                    }
                    else {
                        like($@, qr/You do not have permission to link records/, "Unable to link record without required permission for pass $pass");
                    }
                }

                else { panic "Invalid test: $test" }

                if ($pass == 3)
                {
                    # Remove permission
                    $layout->set_groups([]);
                    $layout->write;
                }
            }
        }
    }
}


done_testing();
