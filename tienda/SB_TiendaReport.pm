package SB_TiendaReport;

# A subroutine library that provides methods for reporting
# and sorting inventory, sales and orders.

# SB_TiendaReport.pm Copyright (C) 2006-2007 Bill G. Bohling
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

@ISA = qw(SB_Bajo);
use strict;
use SB_Bajo;

sub nuevo {
  my $type = shift;
  my $self = shift;
  $self->{period} = shift;
  $self->{product} = shift;
  $self->{status} = shift;
  bless $self, $type;
  $self->init;
  return $self;
}

sub init {
  my $self = shift;
  $self->SUPER::bajo_init;
}

sub inventory {
  my $self = shift;
  my $period = $self->{period};
  my $product_list = $self->{database}->list_all_products($period);
  # for printing
  $period ||= '';
  # list of keys in order of count
  my @sorted_list = sort { $product_list->{$a}{AvailableCount} <=> $product_list->{$b}{AvailableCount} } keys %{$product_list};

  my $sort_by = $self->{sort_by} || 'count_asc';
  for ($sort_by){
      /count_asc/ and do {
        @sorted_list = sort { $product_list->{$a}{AvailableCount} <=> $product_list->{$b}{AvailableCount} } keys %{$product_list};
        last;
      };
      /count_desc/ and do {

        @sorted_list = sort { $product_list->{$b}{AvailableCount} <=> $product_list->{$a}{AvailableCount} } keys %{$product_list};
        last;
      };
      /price_desc/ and do {
        @sorted_list = sort { $product_list->{$b}{Price} <=> $product_list->{$a}{Price} } keys %{$product_list};
        last;
      };
      /price_asc/ and do {
        @sorted_list = sort { $product_list->{$a}{Price} <=> $product_list->{$b}{Price} } keys %{$product_list};
        last;
      };
      /latest_sale/ and do {
        @sorted_list = sort { $product_list->{$b}{LastSale} cmp $product_list->{$a}{LastSale} } keys %{$product_list};
        last;
      };
      /oldest_sale/ and do {
        @sorted_list = sort { $product_list->{$a}{LastSale} cmp $product_list->{$b}{LastSale} } keys %{$product_list};
        last;
      };
    }


  print <<HTML;
<HR>
<b><a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Sales%20Reports>Sales Reports</a></b>&nbsp;<b><a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Order%20Reports>Order Reports</a></b>
<P>
HTML

  if (-e '../../manual'){
      print <<HTML;
<P class-normal style="font-size:10px;font-weight:bold;">
<a href=$self->{home_URL}/manual/Reports.html target=_new>Online Help</a>&nbsp;<SPAN style="font-weight:normal;">(opens in a new window)</SPAN>
HTML
</P>
  }
  print <<HTML;
<TABLE align=center width=100%>
HTML

    my $stock_lines = $self->{database}->list_stock_lines;

    foreach my $product_line (sort @{$stock_lines}){
      print <<HTML;
<TR>
<TD><b>$product_line</b></TD>
</TR>
<TR>
<TD>
<TABLE border=1 width=90% align=center>
<TR>
<TD style="font-size:10px;text-align:center;">
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Inventory%20Reports&sort_by=count_desc class=reports>v</a>
&nbsp;Count&nbsp;
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Inventory%20Reports&sort_by=count_asc class=reports>&#94;</a>
</TD>
<TD style="font-size:10px;font-weight:bold;padding:left:5px;">Product ID</TD>
<TD style="width:200px;font-size:10px;font-weight:bold;padding-left:5px;">Product Name</TD>
<TD style="font-size:10px;text-align:center;">
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Inventory%20Reports&sort_by=price_desc class=reports>v</a>
&nbsp;Price&nbsp;
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Inventory%20Reports&sort_by=price_asc class=reports>&#94;</a>
</TD>
<TD style="font-size:10px;text-align:center;">
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Inventory%20Reports&sort_by=latest_sale class=reports>v</a>
&nbsp;Last Sale&nbsp;
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Inventory%20Reports&sort_by=oldest_sale class=reports>&#94;</a>
</TD>
</TR>
HTML

    foreach my $item (@sorted_list){
      next unless $product_list->{$item}{ProductLine} =~ /$product_line/;
      # now make a fancy link string
      my $url_name = $self->url_map($product_list->{$item}{ProductName});
      my $product_name = <<HTML;
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Sales%20Reports&product=$product_list->{$item}{ProductID}&prod_name=$url_name class=period>$product_list->{$item}{ProductName}</a>
HTML
      print <<HTML;
<TR>
<TD style="text-align:right;padding-right:5px;font-weight:normal;">$product_list->{$item}{AvailableCount}</TD>
<TD style="text-align:left;padding-left:5px;font-weight:normal;">$product_list->{$item}{ProductID}</TD>
<TD style="text-align:left;padding-left:5px;font-weight:normal;">$product_name</TD>
<TD style="text-align:right;padding-right:5px;width:70px;font-weight:normal;">$product_list->{$item}{Price}</TD>
<TD style="text-align:center;font-weight:normal;">$product_list->{$item}{LastSale}</TD>
</TR>
HTML
    }

    print <<HTML;
</TABLE>
<P>
</TD>
</TR>
HTML
  }
  print '</TABLE>';
}

sub sales {
  my $self = shift;
  my $period = $self->{period};
  my $product = $self->{product};
  my $sales = $self->{database}->get_sales($period, $product);
  $period ||= '';
  $product ||= '';
  
  # a list to sort keys into
  my @sorted_list;
  my $sort_by = $self->{sort_by} || 'latest_sale';
  for ($sort_by){
    /sales_desc/ and do {
      # total, descending
      @sorted_list = sort {$sales->{$b}{Sold} <=> $sales->{$a}{Sold}} keys %{$sales}; 
      last;
    };
    /sales_asc/ and do {
      # total, ascending
      @sorted_list = sort {$sales->{$a}{Sold} <=> $sales->{$b}{Sold}} keys %{$sales};
      last;
    };
    /oldest_sale/ and do {
      # oldest => most recent
      @sorted_list = sort {$sales->{$a}{SaleDate} cmp $sales->{$b}{SaleDate}} keys %{$sales};
      last;
    };
    /latest_sale/ and do {
      # most recent => oldest
      @sorted_list = sort {$sales->{$b}{SaleDate} cmp $sales->{$a}{SaleDate}} keys %{$sales};
      last;
    };
    /orders_desc/ and do {
      @sorted_list = sort {$sales->{$b}{Orders} <=> $sales->{$a}{Orders}} keys %{$sales};
      last;
    };
    /orders_asc/ and do {
      @sorted_list = sort {$sales->{$a}{Orders} <=> $sales->{$b}{Orders}} keys %{$sales};
      last;
    };
    # default to date from most recent 
    @sorted_list = sort {$sales->{$b}{SaleDate} cmp $sales->{$a}{SaleDate}} keys %{$sales};
  }

  print <<HTML;
<HR>
<b><a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Inventory%20Reports>Inventory Reports</a></b>&nbsp;<b><a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Order%20Reports>Order Reports</a></b>
</P>
HTML
  if (-e '../../manual'){
      print <<HTML;
<P class-normal style="font-size:10px;font-weight:bold;"><a href=$self->{home_URL}/manual/Reports.html target=_new>Online Help</a>&nbsp;<SPAN style="font-weight:normal;">(opens in a new window)</SPAN>
</P>
HTML
  }
  print <<HTML;
<P class=normal>
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Sales%20Reports>Click here</a> to get all listings back.
</P>
<TABLE border=1 align=center width=90%>
<TR colspan=3>
<TD style="font-size:10px;width:90px;">
&nbsp;<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Sales%20Reports&sort_by=latest_sale&period=$period&product=$product class=reports>v</a>&nbsp;<b>Sale Date</b>&nbsp;<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Sales%20Reports&sort_by=oldest_sale&period=$period&product=$product class=reports>&#94;</a>&nbsp;
</TD>

<TD style="font-size:10px;font-weight:bold;"><b>Product ID--Name</b></TD>
<TD style="font-size:10px;width:65px;">
&nbsp;<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Sales%20Reports&sort_by=sales_desc&period=$period&product=$product class=reports>v</a>
&nbsp;<b>Sold</b>&nbsp;
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Sales%20Reports&sort_by=sales_asc&period=$period&product=$product class=reports>&#94;</a>&nbsp;
</TD>

<TD style="font-size:10px;width:87px;">&nbsp;
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Sales%20Reports&sort_by=orders_desc&period=$period&product=$product class=reports>v</a>
&nbsp;<b>Orders</b>&nbsp;
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Sales%20Reports&sort_by=orders_asc&period=$period&product=$product class=reports>&#94;</a>
</TD>


</TR>
HTML

  my ($total_sold, $total_orders) = 0;
  my $prod_name;
  foreach my $item (@sorted_list){
    next unless (defined ($sales->{$item}{SaleDate}));
    $prod_name = $sales->{$item}{ProductName};
    $total_sold += $sales->{$item}{Sold};
    $total_orders += $sales->{$item}{Orders};
    my ($sYear,$sMonth,$sDay) = split '-', $sales->{$item}{SaleDate};
    # now make some fancy link strings
    my $url_name = $self->url_map($sales->{$item}{ProductName});
    my $product_tag = <<HTML;
$sales->{$item}{ProductID} -- <a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Sales%20Reports&product=$sales->{$item}{ProductID}&prod_name=$url_name class=period>$sales->{$item}{ProductName}</a>
HTML
    my $sale_date = <<HTML;
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Sales%20Reports&product=$product&period=$sYear class=period>$sYear</a>-<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Sales%20Reports&product=$product&period=$sYear-$sMonth class=period>$sMonth</a>-<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Sales%20Reports&product=$product&period=$sYear-$sMonth-$sDay class=period>$sDay</a>
HTML
    my $orders = <<HTML;
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Order%20Reports&product=$sales->{$item}{ProductID}&prod_name=$url_name&period=$sYear-$sMonth-$sDay class=period>$sales->{$item}{Orders}</a>
HTML

    print <<HTML;
<TR>
<TD align=center>$sale_date</TD>
<TD>$product_tag</TD>
<TD align=right>$sales->{$item}{Sold}</TD>
<TD align=center>$orders</TD>
</TR>
HTML
  }
  if ($product){
      print <<HTML;
<TR>
<TD colspan=2 align=right>
<SPAN style="font-size:10px;font-weight:bold;">$prod_name&nbsp;&nbsp;$period&nbsp;&nbsp;Totals:</SPAN>
</TD>
<TD style="text-align:center;font-weight:bold;">$total_sold</TD>
<TD style="text-align:center;font-weight:bold;">$total_orders</TD></TR>
HTML
  }

}

sub orders {
  my $self = shift;
  my $period = $self->{period};
  my $status = $self->{status};
  my $product = $self->{product};
  $period ||= '';
  $status ||= '';
  $product ||= '';
  my $item_name = $self->url_map($self->{prod_name});
  $item_name ||= '';
  my $orders_hash = $self->{database}->list_orders($period,$status,$product);

  my $total_orders = 0;
  my $total_sales = 0;
  my $open_orders = 0;
  my $pending_total = 0;
  for (keys %{$orders_hash}){
    next if ($orders_hash->{$_}{ShipDate} !~ /\d-\d|Open Order/);
    $total_orders++;
    if ($orders_hash->{$_}{ShipDate} =~ /Open Order/){
      $open_orders++;
      $pending_total += $orders_hash->{$_}{SaleTotal};
    } else {
      $total_sales += $orders_hash->{$_}{SaleTotal};
    }
  }
  my $average_sale = 0;
  my $open_avg;
  if (($total_orders > 0) and ($total_orders != $open_orders)){
    $average_sale = $total_sales/($total_orders - $open_orders);
  }
  if ($open_orders > 0){
      $open_avg = $pending_total/$open_orders;
  }
  $average_sale ||= 0;
  $open_avg ||= 0;
  $average_sale = sprintf "%1.2f", $average_sale;
  $open_avg = sprintf "%1.2f", $open_avg;

  my @sorted_keys;
  my $sort_by = $self->{sort_by} || 'order_desc';
  for ($sort_by){
    /ship_desc/ and do {
      @sorted_keys = sort {$orders_hash->{$b}{ShipDate} cmp $orders_hash->{$a}{ShipDate}} keys %{$orders_hash};
      last;
    };
    /ship_asc/ and do {
      @sorted_keys = sort {$orders_hash->{$a}{ShipDate} cmp $orders_hash->{$b}{ShipDate}} keys %{$orders_hash};
      last;
    };
    /ord_desc/ and do {
      @sorted_keys = sort {$orders_hash->{$b}{OrderDate} cmp $orders_hash->{$a}{OrderDate}} keys %{$orders_hash};
      last;
    };
    /ord_asc/ and do {
      @sorted_keys = sort {$orders_hash->{$a}{OrderDate} cmp $orders_hash->{$b}{OrderDate}} keys %{$orders_hash};
      last;
    };
    /amt_desc/ and do {
      @sorted_keys = sort {$orders_hash->{$b}{SaleTotal} <=> $orders_hash->{$a}{SaleTotal}} keys %{$orders_hash};
      last;
    };
    /amt_asc/ and do {
      @sorted_keys = sort {$orders_hash->{$a}{SaleTotal} <=> $orders_hash->{$b}{SaleTotal}} keys %{$orders_hash};
      last;
    };
    /order_desc/ and do {
      @sorted_keys = sort {$orders_hash->{$b}{OrderNumber} <=> $orders_hash->{$a}{OrderNumber}} keys %{$orders_hash};
      last;
    };
    /order_asc/ and do {
      @sorted_keys = sort {$orders_hash->{$a}{OrderNumber} <=> $orders_hash->{$b}{OrderNumber}} keys %{$orders_hash};
      last;
    };
  }

  print <<HTML;
<HR>
<b><a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Sales%20Reports>Sales Reports</a></b>&nbsp;<b><a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Inventory%20Reports>Inventory Reports</a></b>
</P>
HTML
  if (-e "$self->{doc_root}/manual"){
     print <<HTML;
<P class-normal style="font-size:10px;font-weight:bold;">
<a href=$self->{home_URL}/manual/Reports.html target=_new>Online Help</a>&nbsp;<SPAN style="font-weight:normal;">(opens in a new window)</SPAN>
</P>
HTML
  }
  print <<HTML;
<P class=normal>
<a href=$self->{admin_CGI}?page_type=Order%20Reports>Click here</a> to get all listings back.
</P>
<TABLE border=1 align=center width=750px>
HTML
    if ($product || $period){
      my $order_status = '';
      if ($status =~ /shipped/){
	$order_status = 'Orders Shipped';
      } else {
	$order_status = 'Orders Received';
      }
      if ($period =~ /Open Order/){
	$order_status = 'Open Orders';
	$period = '';
      }
      print <<HTML;
<TR>
<TD colspan=5 style="text-align:left;font-weight:bold;padding-left:10px;">
$order_status:&nbsp;&nbsp; $self->{prod_name}&nbsp;&nbsp;$period
</TD>
</TR>
HTML
    }

    print <<HTML;
<TR>
<TD colspan=3 valign=top>
<b>$total_orders</b> Total Orders<br>
HTML
    if ($open_orders > 0){
      print qq(<b>$open_orders</b> Open Orders);
    }
    print <<HTML;
</TD>
<TD colspan=2 align=right valign=top>
Average Closed Sale: &nbsp;&nbsp;<b>$self->{currency}$average_sale</b><br>
HTML
    if ($open_orders > 0){
      print qq(Average Open Order: &nbsp;&nbsp;<b>$self->{currency}$open_avg</b>);
    }
    print <<HTML;
</TD>
</TR>
<TR>
<TD style="text-align:center;width:75px;font-size:10px;">
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Order%20Reports&sort_by=order_desc class=reports>v</a>
&nbsp;<b>Order #</b>&nbsp;
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Order%20Reports&sort_by=order_asc class=reports>&#94;</a>
</TD>
<TD style="text-align:center;width:90px;text-align:center;font-size:10px;">
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Order%20Reports&sort_by=ord_desc&period=$period&status=$status&product=$product&prod_name=$item_name class=reports>v</a>
&nbsp;<b>Order Date</b>&nbsp;
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Order%20Reports&sort_by=ord_asc&period=$period&status=$status&product=$product&prod_name=$item_name class=reports>&#94;</a>
</TD>
<TD style="text-align:center;width:90px;text-align:center;font-size:10px;">
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Order%20Reports&sort_by=ship_desc&period=$period&status=$status&product=$product&prod_name=$item_name class=reports>v</a>
&nbsp;<b>Ship Date</b>&nbsp;
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Order%20Reports&sort_by=ship_asc&period=$period&status=$status&product=$product&prod_name=$item_name class=reports>&#94;</a>
</TD>
<TD style="width:200px;font-weight:bold;font-size:10px;">Shopping Cart</TD>
<TD style="width:90px;text-align:center;font-size:10px;">
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Order%20Reports&sort_by=amt_desc&period=$period&status=$status&product=$product&prod_name=$item_name class=reports>v</a>
&nbsp;<b>Sale Amt</b>&nbsp;
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Order%20Reports&sort_by=amt_asc&period=$period&status=$status&product=$product&prod_name=$item_name class=reports>&#94;</a>
</TD>
<TD style="width:60px;text-align:center;font-size:10px;"><b>Sales Tax</b></TD>
<TD style="width:60px;text-align:center;font-size:10px;"><b>Shipping</b></TD>
</TR>
HTML
  foreach my $order (@sorted_keys){
    my $item_name;
    if ($self->{prod_name}){
      $item_name = $self->url_map($self->{prod_name});
    }
    $item_name ||= '';
    my $ship_date = $orders_hash->{$order}{ShipDate}; 
    my ($oYear,$oMonth,$oDay) = split '-', $orders_hash->{$order}{OrderDate};
    my $order_date = <<HTML;
<a href=$self->{admin_CGI}?page_type=Order%20Reports&period=$oYear&product=$product&prod_name=$item_name class=period>$oYear</a>-<a href=$self->{admin_CGI}?page_type=Order%20Reports&period=$oYear-$oMonth&product=$product&prod_name=$item_name class=period>$oMonth</a>-<a href=$self->{admin_CGI}?page_type=Order%20Reports&product=$product&prod_name=$item_name&period=$oYear-$oMonth-$oDay class=period>$oDay</a>
HTML
    my $ship_date_url;
    if ($ship_date =~ /\d-\d/){
      my ($sYear,$sMonth,$sDay) = split '-', $ship_date;
      # now make a fancy link string
      $ship_date_url = <<HTML;
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Order%20Reports&period=$sYear&status=shipped&product=$product&prod_name=$item_name class=period>$sYear</a>-<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Order%20Reports&period=$sYear-$sMonth&status=shipped&product=$product&prod_name=$item_name class=period>$sMonth</a>-<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Order%20Reports&period=$sYear-$sMonth-$sDay&status=shipped&product=$product&prod_name=$item_name class=period>$sDay</a>
HTML
    } else {
      # ship_date isn't a number and might have spaces, et al
      my $period = $self->url_map($ship_date);
      $ship_date_url = <<HTML;
<a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Order%20Reports&period=$period&status=shipped&product=$product&prod_name=$item_name class=period>$ship_date</a>
HTML
    }
    my @items = split "\n", $orders_hash->{$order}{CartContents};
    print <<HTML;
<TR>
<TD valign=top style="text-align:right;padding-right:10px;"><a href=$self->{admin_CGI}?page_type=Update+Order&order_number=$orders_hash->{$order}{OrderNumber} class=reports>$orders_hash->{$order}{OrderNumber}</a></TD>
<TD valign=top align=center>$order_date</TD>
<TD valign=top align=center>$ship_date_url</TD>
<TD valign=top>
HTML
    foreach my $item (@items){
      my ($catalog_id, $name, $price, $shipping, $quantity) = split "\t", $item;
      my $url_name = $self->url_map($name);
      print <<HTML;
$quantity x <a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Order%20Reports&product=$catalog_id&prod_name=$url_name class=period>$name</a><br>
HTML
    }
    my $sale_total = $orders_hash->{$order}{SaleTotal} || 0;
    $sale_total = sprintf "%1.2f", $sale_total;
    print <<HTML;
</TD>
<TD style="width:60px;text-align:right;"> $self->{currency}$sale_total</TD>
<TD style="width:60px;text-align:right;"> $orders_hash->{$order}{SalesTax}</TD><TD style="width:60px;text-align:right;"> $orders_hash->{$order}{Shipping}</TD>
</TR>
HTML
  }
  print <<HTML;
</TABLE>
HTML
}

sub welcome {
  my $self = shift;

  print <<HTML;
<HR>
<P class=normal>
<b><a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Sales%20Reports>Sales Reports</a></b>--Sales figures listed by date and product<br>
<b><a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Order%20Reports>Order Reports</a></b>--Order dates, shipping status, items, sale amount<br>
<b><a href=$self->{home_URL}/cgi-bin/admin/$self->{admin_CGI}?page_type=Inventory%20Reports>Inventory Reports</a></b>--Inventory figures by product line
</P>
HTML

}

sub url_map {
  my $self = shift;
  my $input = shift;
  return if (!$input);
  my $output = $input;
  map { s/\s/%20/g;
        s/\&/%26/g;
        s/\#/%23/g;
      } $output;
  return $output;
}

1;
