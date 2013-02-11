package SB_CestoDB;

# SB_CestoDB handles all database transactions for the 
# shopping cart and checkout functions 

# To use this module independently, you will have to edit
# init() per the instructions you will find there

# SB_CestoDB.pm Copyright (C) 2006-2007 Bill G. Bohling
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the
# Free Software Foundation, Inc.
# 51 Franklin Street, Fifth Floor,
# Boston, MA  02110-1301, USA.


use strict;
use SB_Bajo;

# avoid warnings about redefining new()
sub nuevo {
  my $type = shift;
  my $self = {};
  bless $self, $type;
  $self->{dbh} = shift;
  $self->init;
  return $self;
}

sub init {
  my $self = shift;

  # edit these values to match your environment
  # the table containing your product data
  $self->{products_table} = 'Products';

  # the column you want to select on; either a unique name
  # or number in your products table
  $self->{identifier} = 'ProductID';
 
  # the columns to select from your table
  # you should at least select a name and price, e.g.
  # $self->{select_columns} = q(SDK_No, Description, price);
  # note that this is a string of comma-separated column
  # names, not an array
  $self->{select_columns} = q(ProductID, ProductLine, ProductName, Price, Discount, Shipping, Shipping2, Weight);

  # The following is the list of column names the shopping cart
  # knows about.  Substitute the equivalent names from your
  # select_columns for the values on the right--e.g., per the
  # e.g. above,
  # ProductID   => 'SDK_No',
  # ProductName => 'Description',
  # Price       => 'price',
  # while the rest of the list stays the same
  $self->{map_columns} = {ProductID   => 'ProductID',
			  ProductName => 'ProductName',
			  ProductLine => 'ProductLine',
			  Price       => 'Price',
			  Discount    => 'Discount',
			  Shipping    => 'Shipping',
			  Shipping2   => 'Shipping2',
			  Weight      => 'Weight'
			 };

  # make sure we have a carts table
  $self->new_cart;

  return $self;
} # end init

# take care of special characters in input so SQL
# doesn't cack
sub sql_sanitize {
  my $self = shift;
  my $input = shift;
  my $input_type = ref($input);

  for ($input_type){
    /ARRAY/ and do {
      map {
            s/\'/\\'/g;
          } @$input;
      last;
    };
    /HASH/ and do {
      map {
            $input->{$_} ||= '';
            $input->{$_} =~ s/\'/\\'/g;
            /comment|Description|instrux/i and do {
            # take care of a little HTML while we're here 
              map {
                    s/<br>//g;
                    s/\n/<br>/g;
                  } $input->{$_};
            };
            /price|Shipping|Weight|Available/i and do {
              $input->{$_} =~ s/[A-Z]|[a-z]//g;
            };
          } (keys %{$input});
      last;
    };
    map {
          s/\'/\\'/g;
        } $input;
  }
  return $input;
} #end sanitize_input


sub new_cart {
  my $self = shift;
  my $shopper_id = shift;

  my $new_cart = <<STMT;
create table if not exists Carts_Table (
Cart VARCHAR(64) NOT NULL,
ProductID MEDIUMINT(8),
ProductLine VARCHAR(60),
ProductName VARCHAR(60) NOT NULL,
Price DECIMAL(10,2),
Discount VARCHAR(6),
Shipping DECIMAL(6,2),
Shipping2 DECIMAL(6,2),
Weight SMALLINT(6),
Quantity MEDIUMINT(10),
add_time VARCHAR(16),
PRIMARY KEY (Cart, ProductName)

)
STMT
  my $sth = $self->{dbh}->prepare($new_cart) or warn "Couldn't create new shopping cart\n";
  $sth->execute;
}

sub got_cart {
  my $self = shift;
  my $cart = shift;
  $cart ||= '';
  my $find_cart = <<STMT;
select * from Carts_Table where Cart = '$cart';
STMT

  my $got_cart = $self->{dbh}->selectall_hashref($find_cart,'Cart');
  my $keys = keys %$got_cart;
  return $keys;
}

sub get_cart_contents {
  my $self = shift;
  my $cart = shift;
  my ($get_cart, $cart_ref) = undef;
  if ($cart){
    $get_cart = <<STMT;
select * from Carts_Table where Cart = '$cart'
STMT
    # all we get is for cart, so key on product name
    $cart_ref = $self->{dbh}->selectall_hashref($get_cart, 'ProductName');
  }
  return $cart_ref;
}

sub update_cart {
  my $self = shift;
  my $cart = shift;
  my $item_ref = shift;
  my $update_item;

  if ($item_ref->{Quantity} > 0){
    my $add_time = time;
    $item_ref = $self->sql_sanitize($item_ref);
    $update_item = <<STMT;
replace into Carts_Table values (
'$cart',
'$item_ref->{ProductID}',
'$item_ref->{ProductLine}',
'$item_ref->{ProductName}',
'$item_ref->{Price}',
'$item_ref->{Discount}',
'$item_ref->{Shipping}',
'$item_ref->{Shipping2}',
'$item_ref->{Weight}',
'$item_ref->{Quantity}',
'$add_time'
)
STMT
  } else {
    $update_item = <<STMT;
delete from Carts_Table where Cart = '$cart' and ProductName = '$item_ref->{ProductName}'
STMT
  }
  my $sth = $self->{dbh}->prepare($update_item) or warn "Couldn't update $item_ref->{prod_id} in $cart\n";
  $sth->execute;

}

sub empty_cart {
  my $self = shift;
  my $cart = shift;

  my $drop_stmt = qq(delete from Carts_Table where Cart = '$cart');

  my $sth = $self->{dbh}->prepare($drop_stmt) or warn "Couldn't drop table $cart\n";
  $sth->execute;
}

sub retrieve_item {
  my $self = shift;
  my $prod_id = shift;

  my $get_item = <<STMT;
select $self->{select_columns} from $self->{products_table} where $self->{identifier} = $prod_id
STMT

  my $row_ref = $self->{dbh}->selectrow_hashref($get_item);

  # map user columns to column names cart knows about
  my $map_fields = $self->{map_columns};
  my $item_ref = {};
  foreach my $field (keys %{$map_fields}){
    if ($row_ref->{$map_fields->{$field}}){
      $item_ref->{$field} = $row_ref->{$map_fields->{$field}};
    } else {
      $item_ref->{$field} = '';
    }
  }
  return $item_ref;
}


# get rid of carts where people might have bailed before buying
sub police_carts {
  my $self = shift;
  my $good = shift;
  my $query = "DELETE FROM Carts_Table WHERE add_time<$good";
  $self->{dbh}->do($query)
}

sub get_blurb {
  my $self = shift;
  my $location = shift;
  my $select_stmt = <<STMT;
select * from Blurbs
where Location like '$location'
STMT
   my $element = $self->{dbh}->selectrow_hashref($select_stmt);
   $element->{Content} ||= '';
   return $element->{Content};

} # end get_blurb

1;
