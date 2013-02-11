package SB_Cesto;

# SB_Cesto is the shopping cart for SB_Tienda.  It provides
# functions for adding to, displaying updating, retrieving and
# emptying the contents of a shopper's cart.

# SB_Cesto.pm Copyright (C) 2006-2007 Bill G. Bohling
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
#
#################################################################

use Digest::MD5 qw(md5_base64);
use SB_CestoDB;

use strict;

sub nuevo {
  my $type = shift;
  my $self = {};
  bless $self, $type;
  my %params = @_;
  $self->{dbh} = $params{'dbh'};
  $self->{cgi} = $params{'cgi'};
  $self->{currency} = $params{'currency'};
  $self->{tax_rate} = $params{'tax_rate'};
  $self->init;
  return $self;
}

sub init {
  my $self = shift;

  # currency symbol
  # for yen, pounds, euros, etc., you will need to use HTML
  # or character codes, e.g., &pound; or &#163; for pounds
  $self->{currency} ||= '$';

  # tax rate, expressed as a decimal, e.g., 6 for 6% 
  $self->{tax_rate} ||= 0;

  # cart style definitions
  # edit these to change formatting, fonts, colors, etc.

  # size and positioning of the cart
  $self->{cart_style} = q(width:500px;
			  margin-top:25px;
			 );

  # quantity column in cart and invoice
  $self->{quantity_style} = q(border-style:solid;
			      background:white;
			      color:black;
                 	      font-size:12px;
                 	      padding-left:5px;
			     );

  # product description column as presented in invoic3e
  $self->{desc_style} = q(border-style:solid;
			  background:white;
                          color:black;
                          font-size:12px;
                          padding-left:5px;
                          text-align:left;
			  width:375px;
                         );

  # price column as presented in cart and invoice
  $self->{price_style} = q(border-style:solid;
			   background:white;
                           color:black;
                 	   font-size:12px;
                 	   padding-right:5px;
                 	   text-align:right;
			   width:75px;
			  );

  ############## no need to change anything below ###############

  my $cgi_params = $self->{cgi}->Vars;
  foreach my $key (keys %{$cgi_params}){
    $self->{$key} = $cgi_params->{$key};
  } 

  # hook in to database functions
  $self->{database} = SB_CestoDB->nuevo($self->{dbh});

  # lacking CGI input, a default:
  if (!defined($self->{cart_action})){
    $self->{cart_action} = 'My Cart';
  }

  # take the spaces out of the style definitions
  foreach my $key (keys %{$self}){
    $key =~ /style/ and do {
      $self->{$key} =~ s/\s//g;
      next;
    };
    next;
  }

  return $self;
}

sub add_item {
  my $self = shift;
  my $prod_id = shift;
  my $bag;
  my $shopper = $self->{cgi}->cookie('cesto');
  if (! defined($self->{database}->got_cart($shopper))){
    $self->{database}->new_cart($shopper);
  }

  my $new_item = $self->{database}->retrieve_item($prod_id);
  $new_item->{Quantity} = 1;
  $self->{database}->update_cart($shopper, $new_item);
  return $self;
}

sub update_bag {
  my $self = shift;
  my $shopper = $self->{cgi}->cookie('cesto');
  my $bag = $self->{database}->get_cart_contents($shopper);
  my $subtotal = 0;
  foreach my $item (keys %$bag){
    # item-specific quantity identifier 
    my $new_quantity = $bag->{$item}{ProductID}.'quantity';
    if ($self->{$new_quantity} < 0){
      $self->{$new_quantity} = 0;
    }
    if ($self->{$new_quantity} =~ /^[\d\s]*$/){
      $bag->{$item}{Quantity} = $self->{$new_quantity};
    }
    # hash ref for new entry
    my $new_ref;
    for (keys %{$bag->{$item}}){
      $new_ref->{$_} = $bag->{$item}{$_};
    }
    $self->{database}->update_cart($shopper, $new_ref);
  }
  return $self;
}

# display user's shopping cart, with navigation options

sub show_cart {
  my $self = shift;
  my $context = $self->{cart_action};
  $context ||= '';
  my $cart = $self->{cgi}->cookie('cesto');
  my $cart_ref = $self->{database}->get_cart_contents($cart);
  my ($subtotal, $ship_sub) = 0;
  my $blurb = $self->{database}->get_blurb('Check Out');
  $blurb ||= 'Click on the Create Invoice button to generate your invoice.  For your security, the rest of the checkout process will be handled at Paypal.';
  if ($blurb !~ /<p|br|t/i){
    $blurb =~ s/\n/<br>/;
  }

  print '<TABLE align=center cellspacing=0 cellpadding=0 class=cart>';
  if ($self->{cart_action} =~ /Check Out/){
    print <<HTML;
<TR><TD colspan=3>
$blurb
</TD></TR>
HTML
  }
  print '<TR><TD colspan=3>';
  print <<HTML;
<TABLE cellspacing=0 cellpadding=0 align=center style=$self->{cart_style}>
<TR>
<TD style="border-top:1px;border-left:1px;border-bottom:0px;border-right:0px;width:70px;font-weight:bold;$self->{quantity_style}">Quantity</TD>
<TD style="padding-left:5px;border-top:1px;border-left:1px;border-bottom:0px;border-right:1px;font-weight:bold;$self->{desc_style}">Product Description</TD>
<TD style="padding-left:5px;border-top:1px;border-left:0px;border-bottom:0px;border-right:1px;width:75px;font-weight:bold;$self->{price_style}">Price</TD>
</TR>
HTML

  my @sorted_list = sort {$cart_ref->{$b}{Price} <=> $cart_ref->{$a}{Price}} keys %{$cart_ref};
  foreach my $item (@sorted_list){
    next if ($cart_ref->{$item}{Quantity} < 1);
    # a tag for readability: 
    my $new_quantity = $cart_ref->{$item}{ProductID}.'quantity';
    my $discount = $cart_ref->{$item}{Discount};
    $discount ||= 0;
    my $item_cost = $cart_ref->{$item}{Price};
    if ($discount =~ /%/){
      $discount =~ s/%//;
      $discount = $item_cost * $discount/100;
    } 
    $item_cost = $item_cost - $discount;
    $item_cost = sprintf "%1.2f", $item_cost;
    my $cost = $item_cost * $cart_ref->{$item}{Quantity};
    $ship_sub += ($cart_ref->{$item}{Shipping} + ($cart_ref->{$item}{Shipping2} * ($cart_ref->{$item}{Quantity}-1)));
    $subtotal += $cost;
    $cost = sprintf "%1.2f", $cost;

    print <<HTML;
<TR>
<TD style="text-align:center;border-top:1px;border-left:1px;border-bottom:0px;border-right:0px;$self->{quantity_style}">
HTML

    if ($context !~ /Check Out|Invoice|Complete/){
      print $self->{cgi}->textfield (-name => $new_quantity,
                                     -value => $cart_ref->{$item}{Quantity},
                                     -override => 1,
                                     -size => 6,
                                     -maxlength => 6
                                    );
    } else {
      print $cart_ref->{$item}{Quantity};
    }

    print <<HTML;
</TD>
<TD style="border-top:1px;border-left:1px;border-bottom:0px;border-right:1px;$self->{desc_style};font-weight:normal;">$cart_ref->{$item}{ProductName}</TD>
<TD style="border-top:1px;border-left:0px;border-bottom:0px;border-right:1px;$self->{price_style}">$cost</TD>
</TR>
HTML
  }

  $subtotal = sprintf "%1.2f", $subtotal;
  my $tax_cart = sprintf "%1.2f", $subtotal * ($self->{tax_rate}/100);
  $tax_cart ||= 0;
  $ship_sub = sprintf "%1.2f", $ship_sub;
  my $total = sprintf "%1.2f", ($subtotal + $ship_sub + $tax_cart);
  my $tax_tag = '';
  if ($tax_cart > 0){
    $tax_tag = <<HTML;
<TR>
<TD align=right colspan=2 style="padding-right:5px;font-size:13px;border-top:0px;border-left:0px;border-right:1px;border-bottom:0px;border-style:solid;">
$self->{tax_rate}\% Sales Tax<br> 
</TD>
<TD style="border-top:1px;border-left:0px;border-bottom:0px;border-right:1px;$self->{price_style}">$self->{currency}$tax_cart</TD>
</TR>
HTML
  }

  print <<HTML;
<TR>
<TD align=right colspan=2 style="padding-right:5px;font-size:13px;border-top:1px;border-left:0px;border-right:1px;border-bottom:0px;border-style:solid;">
Subtotal<br> 
</TD>
<TD style="border-top:1px;border-left:0px;border-bottom:0px;border-right:1px;$self->{price_style}">$self->{currency}$subtotal</TD>
</TR>
$tax_tag
<TR>
<TD align=right colspan=2 style="padding-right:5px;border-right:1px;border-top:0px;border-left:0px;border-bottom:0px;border-style:solid;">
Shipping<br> 
</TD>
<TD style="border-top:1px;border-left:0px;border-bottom:0px;border-right:1px;$self->{price_style}">$self->{currency}$ship_sub</TD>
</TR>
<TR>
<TD align=right colspan=2  style="padding-left:5px;padding-right:5px;font-weight:bold;font-size:13px;border-right:1px;border-top:0px;border-left:0px;border-bottom:0px;border-style:solid;">
Total<br> 
</TD>
<TD style="padding-left:5px;padding-right:5px;border-top:1px;border-left:0px;border-bottom:1px;border-right:1px;$self->{price_style}">$self->{currency}$total</TD>
</TD>
</TR>
HTML

  if ($context !~ /Check Out|Invoice|Complete/){
    print <<HTML;
<TR>
<TD colspan=3 style="padding-left:40px;padding-right:40px;text-align:left;">
<p>
Change quantities as desired and click Update Cart.  To delete an item, change its quantity to 0 or blank.<br>
To  continue shopping, click on any of the store navigation buttons.
</TD></TR>
HTML
  }
  print '</TABLE>';

  return;
} # end show_invoice_items

sub get_cart {
  my $self = shift;
  my $shopper = $self->{cgi}->cookie('cesto');
  my $bag = $self->{database}->get_cart_contents($shopper);
  return $bag;
}

sub empty_cart {
  my $self = shift;
  my $shopper = shift;
  $self->{database}->empty_cart($shopper);
  return;
}

sub police_carts {
  my $self = shift;
  my $expires = shift;
  $expires ||= undef;   # just to make sure
  my $twenty_four_hours = 86400;   # seconds
  my $time = time;
  if (defined($expires)){
    $expires = ($expires * $twenty_four_hours) + 60;
  } else {
    # expire cart items after 24:01 as default
    $expires = $twenty_four_hours + 60;
  }
  my $threshhold = $time - $expires;
  $self->{database}->police_carts($threshhold);
  print "<P class=normal>Abandoned carts have been cleared</P>";
  return;
}

# some buttons
sub navigation {
  my $self = shift;
  my $context = $self->{cart_action};
  my $errors = shift;
  $context ||= '';
  $errors ||= 0;
  print '<TABLE width=100% align=center>';
  for ($context){
    /Check Out/ and do {
      print '<TR><TD colspan=3>';
      print '</TD></TR>';
        print '<TR><TD colspan=3 class=buttons>';
	print $self->{cgi}->submit(-name => 'cart_action',
                                   -value => 'My Cart',
                                  );
        print $self->{cgi}->submit(-name => 'cart_action',
                                   -value => 'Create Invoice',
                                  );
      print  '</TD></TR>';
      last;
    };
    # else, the defaults
    print '<TR><TD class=buttons colspan=3>';
    print $self->{cgi}->submit(-name => 'cart_action',
                               -value => 'Update Cart',
                              );
    print $self->{cgi}->submit(-name => 'cart_action',
                               -value => 'Keep Shopping',
                              );
    print $self->{cgi}->submit(-name => 'cart_action',
                               -value => 'Check Out',
                              );
    print '</TD></TR>';
    last;
  } # end for page_type buttons
  print '</TABLE>';

    print $self->{cgi}->hidden(-name  => 'return_to',
                               -value => $self->{return_to}
                              );

} # end display_buttons

######################## the end #######################
1;
