package SB_Caja;

# SB_Caja is the checkout environment.  It allows for
# Hack into this to add new payment options to an existing
# store (and please feel free to send improvements to be
# passed along to other users.

# SB_Caja.pm Copyright (C) 2006-2007 Bill G. Bohling
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
use IPC::Open2;

sub init {
  my $self = shift;

  # get site-standard stuff via SB_bajo's init
  $self->SUPER::bajo_init;

  # identify our shopper 
  my $shopper = $self->{cgi}->cookie('cesto');

  return;
}

sub check_out {
  my $self = shift;
  my $order_ref = shift;
  my $thank_you = $self->{database}->get_blurb('Payment Page');
  $thank_you ||= qq(Thank you for shopping at $self->{title}.);

  # make sure there aren't any <form>s to interfere with
  # payment buttons
  print '</form>';

  print <<HTML;
<TR>
<TD align=center colspan=3>
<HR>
<P>
<TABLE width=100% align=center>
<TR>
<TD>
$thank_you
</TD>
</TR>
<TR>
<TD colspan=3 style="text-align:center;">
HTML
  my @payment_options = ('paypal');
  for (@payment_options){
    /paypal/i and do {
      $self->paypal_button($order_ref);
      next;
    };
    /western union/i and do {
      $self->western_union($order_ref);
      next;
    };
    /credit card/i and do {
      $self->credit_card($order_ref);
      next;
    };
    $self->paypal_button($order_ref);
    last;
  }

  print <<HTML;
</TD>
</TR>
<TR>
<TD colspan=3>
<HR> 
</TD>
</TABLE>
</TD>
</TR>
HTML
  return;

}



sub paypal_button {
  my $self = shift;
  my $shopper = $self->{cgi}->cookie('cesto');
  # get cart contents and shipping info somehow
  my $cart_ref = $self->{database}->get_cart_contents($shopper); 
  my $ship_fields = shift;
  # make a cart hashref to send along for encryption
  # so -T won't cack about writing and unlinking a file
  #my $enc_cart = {};
  my $enc_cart = {cmd		=> '_cart',
		  upload	=> 1,
		  business 	=> $self->{paypal_mail},
		  cert_id  	=> $self->{paypal_cert_id},
		  invoice  	=> $ship_fields->{OrderNumber},
		  no_note	=> 0,
		  cancel_return	=> "$self->{home_URL}/cgi-bin/$self->{store_CGI}",
		  return	=> "$self->{home_URL}/cgi-bin/$self->{store_CGI}?page_type=thank_you",
	      };
  my ($current_item, $cart_total) = 0;
  foreach my $item (keys %{$cart_ref}){
    $current_item++;
    # calculate price
    my $discount = $cart_ref->{$item}{Discount} || 0;
    if ($discount =~ /%/){
      $discount =~ s/%//;
      $discount = $cart_ref->{$item}{Price} * $discount/100;
    } 
    my $item_price = $cart_ref->{$item}{Price} - $discount;
    $item_price = sprintf "%1.2f", $item_price;
    $cart_total += $item_price * $cart_ref->{$item}{Quantity};
    # add item to hashref
    $enc_cart->{"item_name_$current_item"} = $cart_ref->{$item}{ProductName};
    $enc_cart->{"amount_$current_item"} = $item_price;
    $enc_cart->{"quantity_$current_item"} = $cart_ref->{$item}{Quantity};
    $enc_cart->{"shipping_$current_item"} = $cart_ref->{$item}{Shipping};
    $enc_cart->{"shipping2_$current_item"} = $cart_ref->{$item}{Shipping2};
  }
  my $tax_rate = $self->{tax_rate} || 0;
  $enc_cart->{tax_cart} = sprintf "%1.2f", $cart_total * $tax_rate/100;

  # make a plain-text cart for testing
  my $test_cart;
  foreach my $key (keys %{$enc_cart}){
    next if ($key =~ /cmd|upload|cert_id|^$/);
    $test_cart .= qq(<input type='hidden' name='$key' value='$enc_cart->{$key}'>\n);
  }
  my $test_button = <<HTML;
<form action=https://www.paypal.com/cgi-bin/webscr method=post>
<input type=submit value="Complete Your Purchase at PayPal"><br>
All you need is a credit card.<br>
<input type='hidden' name='cmd' value='_cart'>
<input type='hidden' name='upload' value='1'>
$test_cart
</form>
HTML
#print $test_button;

  # encrypt that sucker
  my $encrypted = $self->paypal_encrypt($enc_cart);

  # now, the button with the encrypted code
  print <<HTML;
<form action=https://www.sandbox.paypal.com/cgi-bin/webscr method=post>
<input type=submit value="Complete Your Purchase at PayPal"><br>
All you need is a credit card.<br>
For your security all data will be sent encrypted.
<input type=hidden name=cmd value=_s-xclick>
<input type=hidden name=encrypted value="$encrypted">
</form>
HTML

  return;

} # end paypal_button

##### Paypal EWP encryption code
sub paypal_encrypt {
  use IPC::Open2;

  my $self = shift;
  my $tmp_cart = shift;
  # path to openssl
  my $OPENSSL = $self->{openssl};
  # make sure we can execute openssl
  die "Could not execute $OPENSSL: $!\n" unless (-x $OPENSSL);
  # get some handles and fire up openssl with open2
  my ($rfh,$wfh);
  my $pid = open2($rfh, $wfh,
		"$OPENSSL smime -sign -signer $self->{my_public_cert} ".
		"-inkey $self->{my_private_key} -outform der -nodetach -binary " .
		"| $OPENSSL smime -encrypt -des3 -binary -outform pem " .
		"$self->{paypal_cert}")
  || die "Could not run open2 on $OPENSSL: $!\n"; 

  # send the cart ref to openssl
  foreach my $key (keys %{$tmp_cart}){
    print $wfh "$key=$tmp_cart->{$key}\n";
  }
  # close the writer
  close $wfh;
  # read in the lines from openssl
  my @lines = <$rfh>;
  # close the reader
  close $rfh;
  # put it all together and send it back
  my $encrypted = join('', @lines);
  return $encrypted;
}

sub western_union {
  my $self = shift;
  print "western union<br>";
  return;
}

sub credit_card {
  my $self = shift;
  print "credit card<br>";

  # present a form
  # - card type
  # - expiration date
  # - CVS # (or whatever that number on the back is
  # - cardholder name
  # - shipping info => billing info
  # - submit button sends request to authorize.net or
  #   other card payment gateway
  return;
}

######################## the end ###########################

1;
