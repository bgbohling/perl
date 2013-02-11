package SB_Tienda;

# SB_Tienda is the store environment itself.  It displays
# catalog listings and other product-specific content, provides
# a shopping cart, and handles checkout.

# SB_Tienda.pm Copyright (C) 2006-2007 Bill G. Bohling
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
use SB_Cesto;
use Digest::MD5 qw(md5_base64);

sub init {
  my $self = shift;

  # get site-standard stuff via SB_bajo's init
  $self->SUPER::bajo_init;
  if (defined ($self->{cart_action})){
    $self->{page_type} = $self->{cart_action};
  }
  $self->{page_type} ||= 'Store Front';

  # generate a timestamp for the order
    my $localtime = scalar localtime(time);
    my ($day,$month,$date,$time,$year) = split ' ', $localtime;
    $self->{timestamp} = qq($date $month $year $time);
  # make a SQL-format date while we're at it
    map {
        s/Jan/01/;
        s/Feb/02/;
        s/Mar/03/;
        s/Apr/04/;
        s/May/05/;
        s/Jun/06/;
        s/Jul/07/;
        s/Aug/08/;
        s/Sep/09/;
        s/Oct/10/;
        s/Nov/11/;
        s/Dec/12/;
    } $month;
    $date = sprintf "%1.2d", $date;
    $self->{date_shopped} = qq($year-$month-$date);
  # identify our shopper 
  my $shopper = $self->{cgi}->cookie('cesto');
  if ((! defined($shopper)) || ($self->{page_type} =~ /Thank You/)){
    # new customer, give them a cookie
    # get our domain
    my ($http, $domain) = split /\/\//, $self->{home_URL};
    # split domain from path
    my $path;
    ($domain,$path) = split /\//, $domain, 2;
    # domain needs at least two periods for a valid cookie.
    # make sure it has them, in case home_URL is something like
    # http://mybinness.biz:
    $domain = '.'.$domain;
    # make a unique ID for shopper using time and PID
    my $date_hash = md5_base64($self->{timestamp}, $$);
    # make sure $shopper is usable as a SQL table name
    $shopper = $day.$date_hash;
    $shopper =~ s/\W//g;
    $self->{new_shopper} = $self->{cgi}->cookie (
      -name => 'cesto',
      -value => $shopper,
    );
  }
  # make a shopping cart
  $self->{cart} = SB_Cesto->nuevo(cgi => $self->{cgi},
				   dbh => $self->{dbh},
				   currency => $self->{currency},
				   tax_rate => $self->{tax_rate}
				  );
  ($self->{listing_type} = $self->{page_type}) =~ s/\W//g;

  # navigation
  $self->{nav_buttons} = $self->{products};

  if ($self->{detail}){
    $self->{page_type} = 'Detail';
  }

  return;
}


sub show_content {
  my $self = shift;

  my $cart;
  my $div_class = 'main';  
  if ($self->{page_type} =~ /Detail|Invoice/){
    # take up the whole page
    $div_class = 'detail';
  }

  if ($self->{user_agent} !~ /IE/){
    print qq(<DIV class=$div_class>);
  } else {
    print '<TD class=show_content>';
  }

#  if ($self->{cart_action} && ($self->{cart_action} !~ /Cart|Keep Shopping/)){
# make this work!!!
#$self->{secureCGI}=qq(https://pelibuey.local/store_test/cgi-bin/tienda.cgi);
    # so we don't pass around any address information
#    print $self->{cgi}->start_form(-action => $self->{secureCGI});
#  } else {
    # default form
    print $self->{cgi}->start_form;
#  }

  for ($self->{page_type}) {
    /^Detail/ and do {
      $self->show_details;
      last;
    };
    /My Cart/ and do {
      # the shopping cart is kept distinct from navigation
      # for third-party flexibility
      $self->{cart}->show_cart;
      $self->{cart}->navigation;
      last;
    };
    /Add Item/ and do {
      $self->{cart}->add_item($self->{prod_id});
      $self->{cart}->show_cart;
      $self->{cart}->navigation;
      last;
    };
    /Update Cart/ and do {
      $self->{cart}->update_bag;
      $self->{cart}->show_cart;
      $self->{cart}->navigation;
      last;
    };
    /Keep Shopping/ and do {
      $self->keep_shopping;
      last;
    };
    /Check Out/ and do {
      $self->{cart}->show_cart;
      $self->{cart}->navigation;
      last;
    };
    /Create Invoice/ and do {
      $self->finish_order;
      last;
    };
    /Thank You/ and do {
      $self->thank_customer;
      last;
    };
    # otherwise, just show the whole list of available
    # products for the type in question
    $self->show_listings;
    last;
  };
  print $self->{cgi}->end_form;
  if ($self->{user_agent} !~ /IE/){
    print '</DIV>';
  } else {
    print '</TD></TR></TABLE>';
  }
}

sub show_listings {
  my $self = shift;
  # url-encode type for passing as a param
  my $page_type = $self->{page_type};
  $page_type =~ s/\s/%20/g;
  my $no_listings = 1; 
  my $listings_ref;
  (my $product_line = $self->{page_type}) =~ s/\'/\\'/g;
  # get the product type blurb
  my $blurb = $self->{database}->get_blurb($product_line);

  if ($blurb){
    # substitute real values for placeholders
    $blurb = $self->map_user_content($blurb);
  }
  if ($blurb !~ /<p|br|t/i){
    $blurb =~ s/\n/<br>/g;
  }

  print qq(<TABLE valign=top cellspacing=0><TR><TD colspan=$self->{row_listings} class=product_blurb valign=top>);
  print $blurb;
  print '</TD></TR>';
  if ($self->{page_type} !~ /Store Front/){
    my $listings_ref = $self->{database}->get_products($product_line);

     if ((keys %{$listings_ref}) > 0){
       $no_listings = 0;
       # see if user has their own catalog listing layout
       my $user_HTML = $self->{database}->get_blurb('Catalog');
       # give sort a numeric option 
         sub numeric { $a <=> $b };

my $cell_count=0;
       foreach my $ref (sort numeric keys %{$listings_ref}){
       # because each ref in listings_ref is a hash of products
       # grouped by price and ProductID:
         foreach my $product (sort keys %{$listings_ref->{$ref}}){
           if ($user_HTML){
	     if (($cell_count % $self->{row_listings}) == 0){
	       print '<TR>'
	     }
	     # user has their own custom catalog listing layout
	     print qq(<TD class=catalog_listings style="vertical-align:bottom">);
             $self->make_user_listing($listings_ref->{$ref}->{$product}, $user_HTML);
	     print '</TD>';
	     $cell_count += 1;
	     if (($cell_count % $self->{row_listings}) == 0){
               print '</TR>'
             }
           } else {
	     print '<TR><TD class=catalog_listings>';
             $self->make_fancy_card($listings_ref->{$ref}->{$product});
	     print '</TD></TR>';
           } # if ($user_listing)
         } #foreach listing
       }  #for keys listings_ref
     }  # if keys listings_ref
  } # if not store front
  print '</TABLE>';
} # end show_listings

sub make_fancy_card {
  my $self = shift;
  my $listing = shift;
  my $listing_type = $self->{listing_type};
  my $total_cost;
  my $discount = $listing->{Discount} || 0;
  my $sale_price = 0;
  if ($discount =~ /%/){
    $discount =~ s/%//;
    $discount = $listing->{Price} * $discount/100;
  }
  $sale_price = ($listing->{Price} - $discount);
  my $item_price = $sale_price || $listing->{Price};
  if ($listing->{Price} =~ /9999/){
    $listing->{price} = 'N/A';
    $total_cost = 'N/A';
  } else {
    $total_cost = $item_price + $listing->{Shipping};
  }
  $sale_price = sprintf "%1.2f", $sale_price;
  # keep full price for comparison
  my $full_price = sprintf "%1.2f", $listing->{Price};
  $total_cost = sprintf "%1.2f", $total_cost;

  if ($listing_type =~ /Coffee/){
    $listing->{price} = $listing->{price};
  }

  my $image_tag = $self->make_img_tag($listing);

    # show catalog item
    print <<HTML;
<TABLE class=fancy_card>
<TR>
<TD class=ProductName>
$listing->{ProductName}
</TD>
<TD valign=top align=right width=30% style="padding-right:10px;">
Catalog # 
<SPAN class=infobox>
$listing->{ProductID}
</SPAN>
</TD>
</TR>
<TR>
<TD valign=top align=left colspan=2>
  <TABLE width=100% height=100%>
  <TR>
  <TD class=product_image>
   $image_tag
  </TD>
  <TD colspan=2 style="font-size:12px; width:100%; vertical-align:top; text-align:left">
    <TABLE style="height:100%;width:100%;">
     <TR><TD valign=top class=cat_desc>
$listing->{Description}
     </TD>
     </TR>
     <TR>
     <TD class=catalog_price valign=bottom>
     <b>Price</b>&nbsp;&nbsp;&nbsp;&nbsp; 
     <SPAN class="infobox">$self->{currency}$full_price</SPAN><br>
HTML
  if ($sale_price < $full_price){
print qq(<SPAN style="font-weight:bold;color:red">Sale Price&nbsp;&nbsp;&nbsp;&nbsp;</SPAN><SPAN class="infobox">$self->{currency}$sale_price</SPAN><br>);   
  }
  print <<HTML;
     <b>Your cost with shipping&nbsp;
     <SPAN class="infobox">$self->{currency}$total_cost</b></SPAN></TD>
     </TR>
    </TABLE>
  </TD>
  </TR>
  <TR>
  <TD colspan=3 class=buttons>
HTML

  if ($listing->{Price} !~ 'N/A'){
    print $self->add_item_button($listing);
  }
    
    #close out the table 
    print <<HTML;
  </TD>
  </TR>
  </TABLE>
</TD></TR>
</TABLE>
HTML

} # end make_fancy_card


# if the user doesn't like the catalog presentation, they can
# change it, as long as they use the right substitution strings
sub make_user_listing {
  my $self = shift;
  my $listing_ref = shift;
  my $user_HTML = shift;
  my $discount = $listing_ref->{Discount} || 0;
  my $price = $listing_ref->{Price};
  my $sale_price = 0;
  my $sale_tag = '';
  if ($discount =~ /%/){
    $discount =~ s/%//;
    $discount = $listing_ref->{Price} * $discount/100;
  }
  $sale_price = sprintf "%1.2f", ($listing_ref->{Price} - $discount);
  if ($sale_price < $listing_ref->{Price}){
    $sale_tag = <<HTML;
<SPAN style="font-weight:bold;color:red">Sale Price&nbsp;&nbsp;&nbsp;&nbsp;</SPAN><SPAN class="infobox">US\$$sale_price</SPAN><br>
HTML
  }
  
  if ($listing_ref){
    my $image_tag = $self->make_img_tag($listing_ref);
    my $button = $self->add_item_button($listing_ref);
    my $url_name = $listing_ref->{ProductName};
    my $return_to = $self->{return_to} || 'Store+Front';
    $return_to =~ s/\s/%20/g;
    my $ship_total = ($sale_price || $price) + $listing_ref->{Shipping};
    $price = sprintf "%1.2f", $price;
    $ship_total = sprintf "%1.2f", $ship_total;
    # take the user's HTML and substitute actual variable names
    # this line's for Tim Cuffel
    map {
      s/MY_CGI/$self->{store_CGI}/g;
      s/URL_NAME/$url_name/g;
      s/PROD_ID/$listing_ref->{ProductID}/g;
      s/NAME/$listing_ref->{ProductName}/g;
      s/DESCRIPTION/$listing_ref->{Description}/;
      s/PRICE/$price/g;
      s/SALE_TAG/$sale_tag/g;
      s/SHIPPING/$listing_ref->{Shipping}/g;
      s/SHIP_TOTAL/$ship_total/g;
      s/WEIGHT/$listing_ref->{Weight}/;
      s/AVAILABLE/$listing_ref->{AvailableCount}/;
      s/RETURN_TO/$return_to/g;
      s/IMAGE_TAG/$image_tag/;
      s/ADD_BUTTON/$button/;
    } $user_HTML;
    print $user_HTML;
  } else {
    print 'what are you here for?';
  }
  return;
} #end make_user_listing

sub add_item_button {
  my $self = shift;
  my $listing = shift;
    my $return_to = $self->{return_to};
    my $button;

    $button .= $self->{cgi}->start_form;

    $button .= $self->{cgi}->submit( -name => 'page_type',
                              -value => 'Add Item to Shopping Cart'
                            );

    $button .= $self->{cgi}->hidden ( -name => 'prod_id',
                                 -value => $listing->{ProductID}
                             );
    $button .= $self->{cgi}->hidden ( -name => qq($listing->{ProductID}quantity),
                                 -value => 1
                             );
    $button .= $self->{cgi}->hidden(-name  => 'return_to',
                               -value => $self->{return_to}
                              );
    $button .= $self->{cgi}->end_form;
    return $button;
}


# make an image tag
sub make_img_tag {
  my $self = shift;
  my $listing = shift;
  my $image_tag;
  my @images = split ' ', $listing->{ProductFotos};
  my $default_img = qq($self->{photo_URL}/$self->{default_img});
  my $listing_type = $listing->{ProductLine};

  # create the img tag line, based on whether or not
  # there are photos.  if so, show the first one available
  # and wrap it in a link to display all available photos
  # full-size in a new window
  # get a product name for the Details page
  (my $prod_name = $listing->{ProductName}) =~ s/\s/%20/g;
  if (scalar (@images) == 0){  # no photos
    $image_tag= qq(<img src=$default_img width=160 height=1><br><SPAN style="font-size:10px;">No photos available at this time</SPAN>);
  } elsif (scalar (@images) == 1){  # Click for full size
      $image_tag = qq(<a href=$self->{store_CGI}?page_type=Detail&prod_id=$listing->{ProductID}&prod_name=$prod_name&detail=1 class=catalog target=_new><img src=$self->{photo_URL}/$images[0] class=catalog><br><SPAN style="font-size:10px;">Click for full-size photo</SPAN></a>);
  } else {  # Click for more photos
      $image_tag = qq(<a href=$self->{store_CGI}?page_type=Detail&prod_id=$listing->{ProductID}&prod_name=$prod_name&detail=1 class=catalog target=_new><img src=$self->{photo_URL}/$images[0] class=catalog><br><SPAN style="font-size:10px;">Click for more photos</SPAN></a>);
  }
  return $image_tag;
}

# get_class -- returns a stylesheet class value
# according to error status of the given variable
sub get_class {
  my $self = shift;
  my $param = shift;
  my $class = 'invoice_item';
  if ($self->{errors}{$param}){
    $class = 'error';
  }
  return $class;
}

sub get_shipping_info {
  my $self = shift;
  foreach my $key (keys %{$self->{cgi_params}}){
    if ($key =~ /ship/){
      $self->{ship_fields}{$key} = $self->{cgi_params}{$key};
    }
  }
    $self->{ship_fields}{special_instrux} = $self->{cgi_params}{special_instrux};

  return $self;

}

# check for missing fields in shipping info
sub verify_shipping {
  my $self = shift;

  foreach my $field (keys %{$self->{ship_fields}}){
    next if ($field =~ /addr|special/);
    if ($self->{ship_fields}{$field} =~ /^$/){
      ( $self->{errors}{$field} = 1 ) unless ( 
        (($field =~ /ship_zip|ship_state/) && ($self->{ship_fields}{ship_country} !~ /USA.$|united states/i))
      );
    }
  }
#  if (($self->{page_type} =~ /Invoice/) and (! ($self->{ship_fields}{ship_addr1} || $self->{ship_fields}{ship_addr2}))){
#    $self->{errors}{ship_addr} = 1;
#  }

  return;
}


sub keep_shopping {
  my $self = shift;
  $self->{page_type} = $self->{return_to};
  $self->show_listings;
  return;

}

sub finish_order {
    use IPC::Open2;

  my $self = shift;
  my $shopper = $self->{cgi}->cookie('cesto');
  my $bag = $self->{cart}->get_cart($shopper);
  my $existing_order = $self->{database}->get_my_order($shopper);
  if (keys %{$bag}){
    if (! (keys %{$existing_order})){
        # make a new order hash
	my $new_order = {};
        $new_order->{Cart} = $shopper;
        $new_order->{Timestamp} = $self->{timestamp};
        $new_order->{OrderDate} = $self->{date_shopped};
        $new_order->{CartContents} = '';

        # process bag contents
        my $bag_ref = $self->process_bag($bag);
        for (keys %{$bag_ref}){
	  $new_order->{$_} = $bag_ref->{$_};
        }
        $self->{database}->insert_new_order($new_order);
    } else {	# existing order
       # process bag_contents
       my $bag_ref = $self->process_bag($bag);
        for (keys %{$bag_ref}){
	  $existing_order->{$_} = $bag_ref->{$_};
        }
       $self->{database}->update_orders_table($existing_order);
    }
    # retrieve order and display invoice
    my $this_order = $self->{database}->get_my_order($shopper);

    # display invoice with Paypal button
    print <<HTML;
<TR><TD colspan=3 align=center>
<P class=normal>
Please save a copy of this page for your records
</P>
</TD></TR>
<TR>
<TD>
<P class=normal>
<b>Order Number: </b> $this_order->{OrderNumber}<br>
<b>Date: </b> $self->{timestamp}
</P>
</TD>
</TR>
HTML
    
    $self->{cart}->show_cart('Complete');

    use SB_Caja;
    my $caja = SB_Caja->new($self->{config_file});
    $caja->check_out($this_order);
  }
  return $self;
} # finish order


# send customer's order in an email for processing
sub email_order {
  my $self = shift;
  my $order = shift;
  my $mail =  <<MAIL;
To: $self->{info_mail}
Subject: $self->{title} Order \#$order->{OrderNumber} 
From: $order->{ShipEmail}
Reply-To: $order->{ShipEmail}
Cc: $order->{ShipEmail}

***************************************************************
Order $order->{OrderNumber} Received: $order->{Timestamp}

Ship To:
$order->{ShipName}
$order->{ShipAddr1}
MAIL

  if ($order->{ShipAddr2}){
    $mail .= "$order->{ShipAddr2}\n";
  }
  $mail .= <<MAIL;
$order->{ShipCity}, $order->{ShipState} $order->{ShipZip}
$order->{ShipCountry}

***************************************************************
Order $order->{OrderNumber} Contents:

MAIL
  my @items = split "\n", $order->{CartContents};
  my ($total_sale,$subtotal,$ship_total) = 0;
  foreach my $item (@items){
    my ($prod_num,$prod_name,$price,$shipping,$quantity) = split "\t", $item;
    $price = sprintf "%1.2f", $price;
    my $cost = $price * $quantity;
    $cost = sprintf "%1.2f", $cost;
    $subtotal += $cost;
    $subtotal = sprintf "%1.2f", $subtotal;
    $ship_total += $shipping * $quantity;
    $ship_total = sprintf "%1.2f", $ship_total;
    $mail .= qq(\t$quantity x $prod_name \@ $price/ea. = $self->{currency}$cost\n);
  }
  $total_sale = $subtotal + $ship_total;
  $total_sale = sprintf "%1.2f", $total_sale;

  $mail .= <<MAIL;
Subtotal:\t$subtotal
Shipping:\t$ship_total
Total:\t\t$self->{currency}$total_sale

Special Instructions: $order->{Instructions}

***************************************************************
MAIL
  # handles for open2 to use--no pipe!
  my ($rfh, $wfh);
  my $pid = open2($rfh, $wfh, "$self->{sendmail} -t -i")
  || die "Could not run open2 on $self->{sendmail}: $!\n";

  # send the mail
  print $wfh $mail;

  # close the handles
  close $wfh;
  close $rfh;

} # end email


sub check_address {
  my ($self, $address) = @_;
  my $error = undef;

  if ($address =~ /^$/){
    $error = 'Please enter your email address:';
  }
  return $error;
}

sub show_details {
  my $self = shift;

  # get the listing
  my $listing = $self->{database}->get_product_data($self->{prod_id});
  if ($listing){
    # get the photos
    my @fotos = split /\t/, $listing->{ProductFotos};
    my $detail_blurb = $listing->{Details} || '';
    if ($detail_blurb !~ /<p|br|t/i){
      $detail_blurb =~ s/\n/<br>/g;
    }
    print <<HTML;
<TABLE style="width:100%; text-align:center;">
<TR>
<TD>
$detail_blurb
</TD>
</TR>
HTML
    foreach my $foto (@fotos){
      print <<HTML;
<TR>
<TD style="width:640px;">
<img src=$self->{photo_URL}/$foto style="border:1px; border-style:groove;width:640px;height:480px;">
</TD>
</TR>
HTML
    }
  }
  print '</TABLE>';

} # end show_details

sub process_bag {
  my $self = shift;
  my $bag = shift;
  my $order_ref = {};
  $order_ref->{CartContents} = '';
  my $ship_total = 0;
    foreach my $item (keys %{$bag}){
      my $price = $bag->{$item}{Price};
      my $discount = $bag->{$item}{Discount};
      $discount ||= 0;
      my $cost;
      if ($discount =~ /%/){
        $discount =~ s/%//;
        $discount = $price * $discount/100;
      }
      $cost = sprintf "%1.2f", $price - $discount;
      my $shipping = $bag->{$item}{Shipping};
      if ($bag->{$item}{Quantity} > 1){
        $shipping = $bag->{$item}{Shipping} + (($bag->{$item}{Quantity} - 1) * $bag->{$item}{Shipping2});
      }
      $ship_total += $shipping;
      my $thing = join "\t", $bag->{$item}{ProductID}, $bag->{$item}{ProductName}, $cost, $shipping, $bag->{$item}{Quantity};
      $order_ref->{SaleTotal} += $cost * $bag->{$item}{Quantity};
      $order_ref->{CartContents} = qq($thing\n$order_ref->{CartContents});
    }
    $order_ref->{Shipping} = $ship_total;
    # add the tax!
    $order_ref->{SalesTax} = $order_ref->{SaleTotal} * $self->{tax_rate}/100;
    return $order_ref;
}

sub thank_customer {
  my $self = shift;
  my $shopper = $self->{cgi}->cookie('cesto');
  my $cart = SB_Cesto->nuevo(cgi => $self->{cgi},
                             dbh => $self->{dbh},
			    );
  my $blurb = $self->{database}->get_blurb('Thank You Message');
  print $blurb;
  $cart->empty_cart($shopper);
  return;
}

1;
