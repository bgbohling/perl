package SB_TiendaDB;

# SB_TiendaDB handles all database transactions for the 
# other Tienda modules 

# SB_TiendaDB.pm Copyright (C) 2006-2007 Bill G. Bohling
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

sub new{
  my $type = shift;
  my $self = {};
  bless $self, $type;
  $self->{dbh} = shift;
  return $self;
}

sub create_lines_table {
  my $self = shift;
  
  my $create_lines_table = <<STMT;
create table if not exists ProductLines (
ButtonOrder SMALLINT(4) NOT NULL AUTO_INCREMENT,
ProductLine VARCHAR(80),
PRIMARY KEY (ButtonOrder)
)
STMT

  my $sth = $self->{dbh}->prepare($create_lines_table) or die "Couldn't prepare create product lines table statement";
  $sth->execute;
  print 'ProductLines table created<br>';
} # end create_lines_table

sub update_prod_lines {
  my $self = shift;

  my $drop_table = <<STMT;
drop table ProductLines
STMT
  my $sth = $self->{dbh}->prepare($drop_table) or die "Couldn't prepare create product lines table statement";
  $sth->execute;
  $self->create_lines_table;
}

sub add_line {
  my $self = shift;
  my $order = shift;
  my $new_line = shift;
  $new_line = $self->sql_sanitize($new_line);
  my $insert_stmt = <<STMT;
replace into ProductLines values (
'$order',
'$new_line'
)
STMT
   my $sth = $self->{dbh}->prepare($insert_stmt) or die "Couldn't prepare ProductLines insert statement";
   $sth->execute;
}

sub create_products_table {
  my $self = shift;

  my $create_products_table = <<STMT;
create table if not exists Products (
ProductID MEDIUMINT(8) NOT NULL AUTO_INCREMENT,         
ProductLine VARCHAR(60),
ProductName VARCHAR(60),
Description VARCHAR(600),
Details VARCHAR(800),
Price DECIMAL(10,2),
Discount VARCHAR(6),
Shipping DECIMAL(6,2),
Shipping2 DECIMAL(6,2),
Weight SMALLINT(6),
AvailableCount MEDIUMINT(6),
ProductFotos VARCHAR(500),
LastSale DATE,
PRIMARY KEY(ProductID)
)
STMT
  my $sth = $self->{dbh}->prepare($create_products_table);
  $sth->execute or die "Couldn't create products table";
 
  my $alter = <<STMT;
alter table Products AUTO_INCREMENT =  10001
STMT
  $sth = $self->{dbh}->prepare($alter);
  $sth->execute;
  print 'Products table created<br>';
} #end create_products_table


# this is duped in SB_CestoDB, but SB_Bajo needs it without
# needing a shopping cart
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
    # all we get is for cart, so key the ref on product
    $cart_ref = $self->{dbh}->selectall_hashref($get_cart, 'ProductName');
  }
  return $cart_ref;
}

sub create_orders_table {
  my $self = shift;
  
  my $create_orders = <<STMT;
create table if not exists Orders (
OrderNumber MEDIUMINT NOT NULL AUTO_INCREMENT,
Cart VARCHAR(50),
CartContents VARCHAR(500),
SaleTotal DECIMAL(10,2),
SalesTax DECIMAL(6,2),
Shipping DECIMAL(6,2),
Timestamp VARCHAR(20),
OrderDate VARCHAR(20),
ShipDate VARCHAR(20),
Comments VARCHAR(500),
PRIMARY KEY (OrderNumber)
)
STMT

  my $sth = $self->{dbh}->prepare($create_orders) or die "Couldn't prepare create product table statement";
  $sth->execute;
  print 'Orders table created<br>';
} # end create_orders_table

sub create_prod_sales {
  my $self = shift;

  my $create_prod_sales = <<STMT;
create table if not exists ProductSales (
OrderNumber VARCHAR(16) NOT NULL,
SaleDate DATE,
ProductID VARCHAR(8),
ProductName VARCHAR(50),
Quantity SMALLINT(6),
PRIMARY KEY (OrderNumber)
)
STMT
  my $sth = $self->{dbh}->prepare($create_prod_sales) or die "Couldn't prepare create product sales table statement";
  $sth->execute;
  print 'ProductSales table created<br>';
} # end create_prod_sales

sub create_blurbs {
  my $self = shift;

  my $create_blurbs = <<STMT;
CREATE TABLE IF NOT EXISTS Blurbs (
Location VARCHAR(80),
Content VARCHAR(20000),
PRIMARY KEY (Location)
)
STMT

  my $sth = $self->{dbh}->prepare($create_blurbs) or die "Couldn't prepare create product table statement";
  $sth->execute;
  print 'Blurbs table created<br>';
} # end create_blurbs

sub get_all_records {
  # return a hashref of all records in a table
  my $self = shift;
  my $table = shift;

  my $select_stmt = <<STMT;
select * from $table;
STMT

  my $records_ref = $self->{dbh}->selectall_hashref($select_stmt);
  return $records_ref;
}

sub get_product_data {
  # by product ID or name
  my $self = shift;
  my $productID = shift;

  my $select = <<STMT;
SELECT * FROM Products 
WHERE ProductID = '$productID' or ProductName = '$productID'
STMT
  my $row_ref = $self->{dbh}->selectrow_hashref($select);
  return $row_ref; 
} # get_product_data

sub retrieve_item {
  my $self = shift;
  my ($id, $line) = @_;

  my $get_item = <<STMT;
select ProductID, ProductLine, ProductName, Price, Discount, Shipping, Shipping2, Weight from Products where ProductID = $id
STMT

  my $item_ref = $self->{dbh}->selectrow_hashref($get_item);
  return $item_ref;
}


sub get_products {
  my $self = shift;
  my $product_line = shift;

  my $select_statement = qq(
select * from Products
where ProductLine regexp '$product_line'
group by Price,ProductID
);
    my $listings_ref = $self->{dbh}->selectall_hashref($select_statement, [qw(Price ProductID)]) or die "Couldn't get all listings refs";
    return $listings_ref;
} # end get_products

sub get_order {
  my $self = shift;
  my $order_number = shift;
  my $get_order = <<STMT;
select * from Orders
where OrderNumber = '$order_number'
STMT
    my $order_ref = $self->{dbh}->selectrow_hashref($get_order);
    return $order_ref;
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


sub get_product_lines {
  my $self = shift;
  my @prod_list = ();

  my $get_existing = <<STMT;
select * from ProductLines
order by ButtonOrder
STMT

  my $existing = $self->{dbh}->selectall_hashref($get_existing, 'ButtonOrder') or die "Couldn't execute $get_existing";
  sub numeric {$a <=> $b;}
  for (sort numeric keys %{$existing}){
    push @prod_list, $existing->{$_}{ProductLine};
  }
  return @prod_list;
}

sub get_my_order {
  my $self = shift;
  my $shopper = shift;
  #$order_ref = $self->sql_sanitize($order_ref);

  my $select_stmt = qq( 
select * from Orders
where Cart like '$shopper'
);

  my $order = $self->{dbh}->selectrow_hashref($select_stmt);
  return $order;
} # end get_new_order


sub get_sales {
  my $self = shift;
  my $period = shift;
  my $product = shift;
  $period ||= '.*';
  $product ||= '.*';
  my $get_sales = <<STMT;
select *, count(ProductID) as Orders, sum(Quantity) as Sold from ProductSales
where ProductID regexp '$product' and SaleDate regexp '$period'
group by ProductID, SaleDate
STMT
  my $sales_ref = {};
  my $sales_list = $self->{dbh}->selectall_arrayref($get_sales);
  my $row = 0;
  foreach my $record (@$sales_list){
    $row++;
    my @fields = qw(OrderNumber SaleDate ProductID ProductName Quantity Orders Sold);
    foreach my $field (@fields){
      $sales_ref->{$row}{$field} = shift @$record;
    }
  }
  return $sales_ref;
}

sub insert_new_order {
  my $self = shift;
  my $order_ref = shift;
  $order_ref = $self->sql_sanitize($order_ref);

# add shopper id as a field instead of email and use that
# to select the order


  my $replace_stmt = <<STMT;
replace into Orders (Cart,CartContents,SaleTotal,SalesTax,Shipping,Timestamp,OrderDate,ShipDate,Comments) values (
'$order_ref->{Cart}',
'$order_ref->{CartContents}',
'$order_ref->{SaleTotal}',
'$order_ref->{SalesTax}',
'$order_ref->{Shipping}',
'$order_ref->{Timestamp}',
'$order_ref->{OrderDate}',
'Open Order',
''
)
STMT
   my $sth = $self->{dbh}->prepare($replace_stmt) or die "Couldn't insert new order";
   $sth->execute;

} # end insert_new_order

# something to get all product lines that have products in them,
# not just the active lines that show up in buttons and menus
sub list_stock_lines {
  my $self = shift;

  my $get_lines = <<STMT;
select ProductLine from Products
group by ProductLine
STMT
  my $lines = $self->{dbh}->selectcol_arrayref($get_lines);
  return $lines;
}


sub list_all_products {
  my $self = shift;
  my $period = shift;

  my $select_stmt = <<STMT;
select ProductID,ProductLine,ProductName,Price,AvailableCount,LastSale from Products
STMT

  if (defined($period)){
    my ($label, $when) = split '_', $period;
    $select_stmt .= <<STMT;
where LastSale regexp '$period'
STMT
  }
  my $product_list = $self->{dbh}->selectall_hashref ($select_stmt, 'ProductID');
  return $product_list
}

sub list_product_line {
  my $self = shift;
  my $product_line = shift;
  my $get_prods = <<STMT;
select * from Products
where ProductLine regexp '$product_line'
order by ProductID
STMT
  my $prods_ref = $self->{dbh}->selectall_hashref($get_prods, 'ProductID');
  return $prods_ref;
} # end list_product_line

sub list_orders {
  my $self = shift;
  my $period = shift;
  my $status = shift;
  my $product = shift;
  $period ||= '.*';
  $product ||= '.*';

  my $get_orders = <<STMT;
select * from Orders
STMT

    for ($status){
      /shipped/ and do {
      # select by ShipDate
        $get_orders .= <<STMT;
where ShipDate regexp '$period'
STMT
        last;
      };
      # default to order date
      $get_orders .= <<STMT;
where OrderDate regexp '$period'
STMT
      last;
    }
  if ($product){
    $product =~ s/%20/ /g;
    $get_orders .= <<STMT;
and CartContents regexp '$product'
STMT
  }

  my $orders_hash = $self->{dbh}->selectall_hashref($get_orders,'OrderNumber');
  return $orders_hash;
} # end list_orders

sub load_data {
  my $self = shift;
  my $item = shift;
  my $data = {};
  $data->{last_sale} = shift;
  $data->{shipped_date} = shift;
  $data->{OrderNumber} = shift;
  #get info about an item
  my @item_fields = ('catalog_id','name','price','Shipping','quantity');
  my @item_array = split "\t", $item;
  for (@item_fields){
    $data->{$_} = shift @item_array;
  }
  $data->{prod_id} = qq($data->{catalog_id}--$data->{name});
  return $data;
} #end load_item

sub delete_prod {
  my $self = shift;
  my $catalog_id = shift;

  my $delete_stmt = <<DELETE;
delete from Products 
where ProductID = '$catalog_id'
DELETE
  my $sth = $self->{dbh}->prepare($delete_stmt);
  $sth->execute;
}

sub delete_blurb {
  my $self = shift;
  my $discontinued_line = shift;

  my $delete_blurb = <<STMT;
delete from Blurbs 
where Location = '$discontinued_line'
STMT
  my $sth = $self->{dbh}->prepare($delete_blurb);
  $sth->execute;
}


sub delete_product_line {
  my $self = shift;
  my $discontinued_line = shift;
  my $delete_line = <<DELETE;
delete from ProductLines
where ProductLine = '$discontinued_line'
DELETE
  my $sth = $self->{dbh}->prepare($delete_line) or warn "Couldn't prepare delete_line";
  $sth->execute;
}

sub update_product_sales {
  my $self = shift;
  my $data = shift;
  $data = $self->sql_sanitize($data);
      
  # update record
  my $order_key = qq($data->{catalog_id}-$data->{OrderNumber});
  my $update_sales = <<STMT;
replace into ProductSales values (
'$order_key',
'$data->{last_sale}',
'$data->{catalog_id}',
'$data->{name}',
'$data->{quantity}'
)
STMT
  my $sth = $self->{dbh}->prepare($update_sales) or warn "Couldn't prepare product sales update";
  $sth->execute or die "Couldn't update sales table\n";
  #print 'Product Sales table updated<br>';
  return $self;

} # end update_product_sales

sub update_products_table {
  my $self = shift;
  my $new_data = shift;
  $new_data = $self->sql_sanitize($new_data);
  # get the current record
  my $get_product = <<STMT;
select * from Products
where ProductID = '$new_data->{catalog_id}'
STMT
  my $cur_prod = $self->{dbh}->selectrow_hashref($get_product);
  my $new_count;
  if ($new_data->{shipped_date}){
    $new_count = $cur_prod->{AvailableCount} - $new_data->{quantity};
  } else {
    $new_count = $cur_prod->{AvailableCount};
  }
  for (keys %{$cur_prod}){
    $cur_prod->{$_} =~ s/\'/\\'/g;
  }

 # replace Product record
 my $update_products = <<STMT;
replace into Products (ProductID,ProductLine,ProductName,Description,Details,Price,Discount,Shipping,Shipping2,Weight,AvailableCount,ProductFotos,LastSale)
values (
'$cur_prod->{ProductID}',
'$cur_prod->{ProductLine}',
'$cur_prod->{ProductName}',
'$cur_prod->{Description}',
'$cur_prod->{Details}',
'$cur_prod->{Price}',
'$cur_prod->{Discount}',
'$cur_prod->{Shipping}',
'$cur_prod->{Shipping2}',
'$cur_prod->{Weight}',
'$new_count',
'$cur_prod->{ProductFotos}',
'$new_data->{last_sale}'
)
STMT
  my $sth = $self->{dbh}->prepare($update_products);
  $sth->execute or warn "Couldn't update products table";
} # end update_products_table


sub update_product {
  my $self = shift;
  my $product = shift;
  $product = $self->sql_sanitize($product);
  # for first-timers
  $product->{last_sale} ||= 'NULL';
  $product->{ProductID} ||= 'NULL';
  $product->{Discount} ||= 0;

  my $replace_stmt = qq(
replace into Products values (
'$product->{ProductID}',
'$product->{ProductLine}',
'$product->{ProductName}',
'$product->{Description}',
'$product->{Details}',
'$product->{Price}',
'$product->{Discount}',
'$product->{Shipping}',
'$product->{Shipping2}',
'$product->{Weight}',
'$product->{AvailableCount}',
'$product->{fotos}',
'$product->{last_sale}'
)
);

   my $sth = $self->{dbh}->prepare($replace_stmt);
   $sth->execute;


} # end update_product

sub update_orders_table {
  my $self = shift;
  my $current_order = shift;
  $current_order = $self->sql_sanitize($current_order);

  my $replace_order = <<STMT;
replace into Orders values (
'$current_order->{OrderNumber}',
'$current_order->{Cart}',
'$current_order->{CartContents}',
'$current_order->{SaleTotal}',
'$current_order->{SalesTax}',
'$current_order->{Shipping}',
'$current_order->{Timestamp}',
'$current_order->{OrderDate}',
'$current_order->{ShipDate}',
'$current_order->{Comments}'
)
STMT
    my $sth = $self->{dbh}->prepare($replace_order);

    $sth->execute or die "Problem updating record for $current_order->{OrderNumber}: $!\n";

} # end update_orders_table

sub update_blurb {
  my $self = shift;
  my $element = shift;
  my $blurb = shift;
  my $location = $element;
  map {
    s/\'/\\'/g;
    s/\*/\\*/g;
  } ($blurb, $location);

  my $replace_stmt = <<STMT; 
replace into Blurbs values (
'$location',
'$blurb'
)
STMT
  my $sth = $self->{dbh}->prepare($replace_stmt) or die "couldn't prepare insert statement: $!\n";
 $sth->execute or die "couldn't execute insert statement\n";
 print "<P class=normal>The $element element has been updated and is now live on your site.</P>";
} # end update_blurb

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

sub sync_db_tables {
  my $self = shift;
  $self->create_lines_table;
  $self->create_products_table;
  $self->create_orders_table;
  $self->create_prod_sales;
  $self->create_blurbs;
  return;
}

1;
