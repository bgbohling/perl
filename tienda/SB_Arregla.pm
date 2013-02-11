package SB_Arregla;

# Provides all management functionality for a
# SB_Tienda store.  This includes product and catalog
# management, basic order tracking, reporting, and editing of
# site elements and the stylesheet.

# SB_Arregla.pm Copyright (C) 2006-2007 Bill G. Bohling
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
use SB_Bajo;	# inherit new() and a header and footer

sub init {
  my $self = shift;

  # call NR_bajo's init for site-wide stuff
  $self->SUPER::bajo_init;

  # make a place for photos, too
  unless (-e $self->{photo_db}) {
    mkdir $self->{photo_db}, 0777 or warn "$!";
  }

#  if ($self->{page_type} =~ /Welcome Page/){
#    $self->{page_type} = q(Office);
#  }
  $self->{page_type} ||= q(Office);

  # for the menu bar
  @{$self->{nav_buttons}} = ('Update Order','Manage Product Lines','Add Product','Edit Product','Delete Product','Discontinue Product Line','Edit Site Element','Edit Stylesheet','Create Reports','Create Database Tables','Cart Patrol');

  return $self;
}


sub show_content {
  my $self = shift;

  if ($self->{user_agent} !~ /IE/){
    if ($self->{page_type} =~ /Report/){
      print '<DIV class=main style="width:auto;overflow:scroll;">';
    } else {
      print '<DIV class=main>';
    }
  }

  for ($self->{page_type}) {
    /Update Order/ and do {
      $self->update_order;
      last;
    };
    /Site Element/ and do {
      $self->create_blurb;
      last;
    };
    /[Manage|Update] Product Lines/ and do {
      $self->create_new_line;
      last;
    };
    /Discontinue Product Line|NUKE PRODUCT LINE/ and do {
      $self->discontinue_line;
      last;
    };
    /Add Product/ and do {
      $self->add_product;
      last;
    };
    /Edit Product/ and do {
      $self->edit_product;
      last;
    };
    /Update Product/ and do {
      $self->update_listing;
      last;
    };
    /Delete/ and do {
        $self->delete_listing;
	last;
    };
    /Report/ and do {
      use SB_TiendaReport;
      my $report = SB_TiendaReport->nuevo($self, $self->{period}, $self->{product}, $self->{status});
      for ($self->{page_type}) {
        /Inventory Reports/ and do {
	  $report->inventory;
	  last;
	};
	/Sales Reports/ and do {
	  $report->sales;
	  last;
	};
	/Order Reports/ and do {
	  $report->orders;
	  last;
	};
        $report->welcome;
      };
      last;
    };
    /Stylesheet/ and do {
      $self->edit_stylesheet;
      last;
    };
    /Database Tables/ and do {
      $self->{database}->sync_db_tables;
      last;
    };
    /Cart Patrol/ and do {
      $self->cart_patrol;
      last;
    };
    # otherwise, just go to the main management page 
    $self->manage_listings;
  };
  if ($self->{user_agent} !~ /IE/){
    print '</DIV>';
  }
}


sub manage_listings {
  my $self = shift;
  print <<HTML;
<P class=normal>
Welcome to the $self->{title} pages.  From here, you can add and discontinue product lines; add, edit and delete individual product listings; update customer order status; create reports; even create and edit the contents of most of the elements on your store pages.
</P>
<P class=normal>
Select your desired action from the menu.
</P>
HTML

} # manage listings


# add a new product
sub add_product {
  my $self = shift;

    $self->show_data_entry_form;
} # end add_product

# edit data for an existing product
sub edit_product {
  my $self = shift;
  my @lines = $self->{database}->get_product_lines;
  if ($self->{edit_ProductID}) {
    my ($ProductID,$name) = split '--', $self->{edit_ProductID};
    if (! defined($name)){
      $ProductID = $self->{edit_ProductID};
    }
    chomp $ProductID;
    print <<HTML;

<P class=normal style="text-align:center;">
<!--
<SPAN style="font-size:16px;font-Weight:bold">Edit Product</SPAN>
</P>
<P class=normal>
Editing <b>$name</b> in <b>$self->{ProductLine}</b><hr>
-->
HTML
    $self->show_data_entry_form($ProductID);
  } else {
    # wse have nothing at this time, so display a form to
    # select a product type so we can get a list of items
    if (-e '../../manual'){
      print <<HTML;
<P class-normal style="font-size:10px;font-weight:bold;">
<a href=$self->{home_URL}/manual/EditProduct.html target=_new>Online Help</a>&nbsp;<SPAN style="font-weight:normal;">(opens in a new window)</SPAN>
</P>
HTML
    }
    print $self->{cgi}->start_form;
      print '<P class=normal>';
      print 'Select type of product to edit:<br>';
      print $self->{cgi}->scrolling_list(-name => 'ProductLine',
					 -values => [@lines],
					 -size => 1
					);
    my @product_list;
    if ($self->{ProductLine}){
      (my $ProductLine = $self->{ProductLine}) =~ s/\'/\\'/g;
      # display list of products for the type
      my $products = $self->{database}->list_product_line($ProductLine);
      foreach my $listing (sort keys %{$products}){
        push @product_list, "$products->{$listing}{ProductID} -- $products->{$listing}{ProductName}";
      }
    } # if prod type

      if (scalar @product_list > 0){
        print '<P class=normal>';
	print 'Select the product you wish to edit:<br>';
        print $self->{cgi}->scrolling_list(-name => 'edit_ProductID',
	  				   -values => [@product_list],
					   -size => 1
					  );
      }
    print $self->{cgi}->submit(-name => 'page_type',
			       -value => 'Edit Product'
			      );
    print '</P>';
    print $self->{cgi}->end_form;
  }
} # end edit_product



# an ungainly routine to display a data entry  form
sub show_data_entry_form {
  my $self = shift;
  my ($ProductID, $type, $name, $description, $price, $Shipping, $Weight, $count, $fotos, $last_sale);
  $ProductID = shift;
  my @lines = $self->{database}->get_product_lines;
  my $product;
  if ($self->{page_type} =~ /Edit/){
    # load up the data
     $product = $self->{database}->get_product_data($ProductID);
  }

  if (-e '../../manual'){
    print <<HTML;
<P class-normal style="font-size:10px;font-weight:bold;">
<a href=$self->{home_URL}/manual/UpdateProduct.html target=_new>Online Help</a>&nbsp;<SPAN style="font-weight:normal;">(opens in a new window)</SPAN>
</P>
HTML
  }
      print $self->{cgi}->start_multipart_form;
      print '<P class=normal style="font-size:12px;"><b>Product Line:</b>&nbsp;&nbsp;';
      print $self->{cgi}->scrolling_list(-name => 'ProductLine',
					 -values => [@lines],
					 -default => $product->{ProductLine},
					 -size => 1,
					);
      print '<P class=normal style="font-size:12px;"><b>Product Name:</b>&nbsp;&nbsp;';
      print $self->{cgi}->textfield(-name => 'ProductName',
                                    -value => $product->{ProductName},
                            -size => 50,
                            -maxlength => 60,
                            -override => 1,
                           );
      print '<P class=normal style="font-size:12px;"><b>Catalog Description:</b> (for catalog listing)<br> ';
      print $self->{cgi}->textarea(-name => 'Description',
                                   -value => $product->{Description},
                                   -rows => 10,
                                   -columns => 60,
                                   -override => 1,
                          );
      print '<P class=normal style="font-size:12px;"><b>Detailed Description</b> (for Details page)<br>';
      print $self->{cgi}->textarea(-name => 'Details',
                                   -value => $product->{Details},
                                   -rows => 10,
                                   -columns => 60,
                                   -override => 1,
                          );

      print qq(<P class=normal  style="font-size:12px;"><b>Price:</b> $self->{currency});
      print $self->{cgi}->textfield(-name => 'Price',
                                    -value => $product->{Price},
                                    -size => 10,
                                    -maxlength => 10,
                                    -override => 1,
                           );
      print '&nbsp;&nbsp;&nbsp;&nbsp;<b>Discount: </b>';
      print $self->{cgi}->textfield(-name => 'Discount',
                                    -value => $product->{Discount},
                                    -size => 6,
                                    -maxlength => 6,
                                    -override => 1,
                           );
      print '</P>';
      print qq(<P class=normal style="font-size:12px;"><b>Shipping--One Item: </b>$self->{currency});

      print $self->{cgi}->textfield(-name => 'Shipping',
                                    -value => $product->{Shipping},
                                    -size => 6,
                                    -maxlength => 6,
                                    -override => 1,
                                  );
      print "&nbsp;&nbsp;<b>Shipping--Additional Item: </b>$self->{currency}";
      print $self->{cgi}->textfield(-name => 'Shipping2',
                                    -value => $product->{Shipping2},
                                    -size => 6,
                                    -maxlength => 6,
                                    -override => 1,
                                  );
      print '</P><P class=normal style="font-size:12px;"><b>Shipping Weight:</b> ';
      print $self->{cgi}->textfield(-name => 'Weight',
                                    -value => $product->{Weight},
                                    -size => 6,
                                    -maxlength => 6,
                                    -override => 1,
                                  );

      print '&nbsp;&nbsp;<b>On Hand:</b> ';
      print $self->{cgi}->textfield(-name => 'AvailableCount',
                                    -value => $product->{AvailableCount},
                            -size => 10,
                            -maxlength => 10,
                            -override => 1,
                           );
  print '<P style="margin-left:15px;margin-right:15px;font-size:12px;">';
  print '<SPAN style="font-Weight:bold;">Upload photos:</SPAN><br>';
  my @current_photo;
  if ($product->{ProductFotos}){
    @current_photo = split ' ', $product->{ProductFotos};
  }
  # make 10 photo upload fields
  for (my $i=0; $i<=9; $i++){
    $current_photo[$i] ||= '';
    print $self->{cgi}->filefield(-name => "uploaded_photo$i",
				  -default => undef,
				  -size => 27,
				  -maxlength => 80,
				 );
    print 'Save as:';
    print $self->{cgi}->textfield(-name => "save_as$i",
				  -default => "$current_photo[$i]",
				  -size => 30,
				  -maxlength => 30,
				  -override => 1,
				 );
    print '<br>';
  }

  print '<p>';

      print $self->{cgi}->submit(-name => 'page_type',
                         -value => 'Update Product',
                        );
      print $self->{cgi}->reset('Cancel changes');
      print $self->{cgi}->hidden(-name => 'ProductID',
				 -value => $ProductID
				);
      print $self->{cgi}->end_multipart_form;

} # end data_entry_form

sub update_listing {
  my $self = shift;
  my @db_fields = qw(ProductID ProductLine ProductName AvailableCount Description Details Price Discount Shipping Shipping2 Weight);

  my $product_id = $self->{ProductID} || '';

   if (! $self->{ProductName}){
    print <<HTML;
<P class=normal>
Nameless products can not be added to the database.  Please go back and give this product a name.
</P>
HTML
  } elsif (defined($product_id)){
   print 'Updating listing:<br>';

   # deal with photos first
   my @filenames;
   my $save_as;
   my $key;
   my $buffer;
   my $photo;
   my $bytesread;
   my @uploads = ();
   my $fotos;

   # get existing fotolist
   my $listing = $self->{database}->get_product_data($product_id);
  my @old_photos;
  if ($listing->{ProductFotos}){
    @old_photos = split /\t/, $listing->{ProductFotos}; 
  }

   foreach $key (sort keys %{$self}){
     for ($key){
       # this should get all the save_as names first
       (/save_as/)  and do {
         # stash the filename to put in the fotos field
         $self->{$key} =~ s/\s//g;
         push @filenames, $self->{$key};
	 next;
       };

       # then we hit the uploaded photos
       (/uploaded_photo/) and do {
         $photo = $self->{cgi}->param($key);
	 # get the next file name from filenames list
	 # and save in a new list
         if ($save_as = shift @filenames || $photo){
           $save_as =~ s/\s/_/g;
	   push @uploads, $save_as;
         }
	 # if it's a photo, upload it
         if ($photo !~ /^$/){
print qq(<b>upload</b> $photo -- <b>save as:</b> $save_as);
           open OUTFILE, ">$self->{photo_db}/$save_as" or warn qq(couldn't open $save_as: $!\n);;
           while ($bytesread = read($photo,$buffer,1024)){
print '.';
             print OUTFILE $buffer if ($bytesread>0);
           }
print '<br>';
         }
         
         next;
       }; # end /uploaded_photo/

     } #end for ($key)
   } #end foreach key (photos)

   $fotos = join "\t", @uploads;

   # now check old foto list against new one
   # and get rid of any fotos not in the new list
   for (@old_photos){
     if ($fotos !~ /$_/){
       unlink qq($self->{photo_db}/$_);
       print "<b>delete photo</b> $_<br>";
     }
   }
 
     # make a hash to pass to database
     my $new_data;
     foreach (@db_fields){
       $new_data->{$_} = $self->{$_};
     }
     $new_data->{ProductID} = $product_id;
     $new_data->{fotos} = $fotos || '';
     $new_data->{last_sale} = $listing->{LastSale} || '';
     $self->{database}->update_product($new_data);
     my $bad_discount = 0;
     my $discount = $new_data->{Discount};
     if ($discount !~ /%/ and ($discount >= $new_data->{Price})){
       $bad_discount = 1;
     } elsif ($discount =~ /%/){
       $discount =~ s/%//;
       $discount = $new_data->{Price} * $discount/100;
       my $price = sprintf "%1.2f", $new_data->{Price} - $discount;
       if ($price <= 0){
	 $bad_discount = 1;
       }
     }
     foreach (@db_fields){
       next if /ProductID/;
       if (/Discount/ and $bad_discount){
	 print qq(<SPAN style="color:red;font-weight:bold;">Discount will result in a 0 price</SPAN> <a href=$self->{admin_CGI}?page_type=Edit+Product&edit_ProductID=$new_data->{ProductID}>Go back to correct</a><br>);
       }
       print "<b>$_:</b> $new_data->{$_}<br>";
     }
     foreach (split /\t/, $fotos){
       print "<img src = $self->{photo_URL}/$_><br>";
     }

  } #end if ProductID

} # end update 

sub delete_listing {
  my $self = shift;

  if ($self->{delete_prods}){  # we have work to do
    my @delete_prods = $self->{cgi}->param('delete_prods');
    foreach my $delete_prod (@delete_prods){
      print "deleting product <b>$delete_prod</b> from the database<br>";
      my ($delete_id,$delete_name) = split '--', $delete_prod;
      $delete_id =~ s/\s//g;
      # save a reference for foto URLS
      # delete fotos for product
      my $product = $self->{database}->get_product_data($delete_id);  
      for (keys %{$product}){
	print "&nbsp;&nbsp;<b>$_:</b>&nbsp;&nbsp;$product->{$_}<br>";
      }
      if ($product->{ProductFotos} !~ /^$/){
        my @doomed_photos = split ' ', $product->{ProductFotos};
        foreach my $doomed (@doomed_photos){
          unlink "$self->{photo_db}/$doomed";
	  print "&nbsp;&nbsp;&nbsp;&nbsp;deleted $self->{photo_db}/$doomed<br>";
        }
      }
      # delete product from database
      $self->{database}->delete_prod($delete_id);
      print "<b>$delete_prod</b> has been deleted.<hr>"; 
    }
  } else { 
    #display a form
    print $self->{cgi}->start_form;
    my @product_list;
    my @lines = $self->{database}->get_product_lines;
    if (defined $self->{ProductLine}){
      (my $prod_table = $self->{ProductLine}) =~ s/\'/\\'/g;
       
      # get product listings for the type
      my $products = $self->{database}->list_product_line($prod_table);
      foreach my $listing (sort keys %{$products}){
        push @product_list, "$products->{$listing}{ProductID} -- $products->{$listing}{ProductName}";
      }
    }
    if (-e '../../manual'){
      print <<HTML;
<P class-normal style="font-size:10px;font-weight:bold;">
<a href=$self->{home_URL}/manual/DeleteProduct.html target=_new>Online Help</a>&nbsp;<SPAN style="font-weight:normal;">(opens in a new window)</SPAN>
</P>
HTML
    } 
    print '<P class=normal>';
    if (! defined $self->{ProductLine}){
      print 'Select the type of product you wish to delete:<br> ';
      print $self->{cgi}->scrolling_list (-name => 'ProductLine',
                                      -values => [@lines],
                                      -size => 1,
                                     );

    }
    if (scalar @product_list > 0){
      print <<HTML;
Deleting in <b>$self->{ProductLine}</b><br>
Select the product(s) you wish to delete:<br>
HTML
      print $self->{cgi}->scrolling_list (-name => 'delete_prods',
 				     -values => [@product_list],
				     -size => 5,
				     -multiple => 'true'
				    );
      $self->{cgi}->param('ProductLine',$self->{ProductLine});
      print $self->{cgi}->hidden (-name => 'ProductLine',
				  -value => $self->{ProductLine}
				 );
    } else {
      if ($self->{ProductLine}){
        print "No products to delete in <b>$self->{ProductLine}</b>";
	return;
      }
    }
    print $self->{cgi}->submit(-name => 'page_type',
  			     -value => 'Delete Product',
			    );
    print $self->{cgi}->end_form;
  }
  
} # end delete_listing

sub create_blurb{
  my $self = shift;
  my @locations = ('Store Front','Check Out','Payment Page','Thank You Message');
  my @lines = $self->{database}->get_product_lines;
  push @locations, (@lines, 'Top Banner', 'Navigation Panel','Catalog');


  if (-e '../../manual'){
    print <<HTML;
<P class-normal style="font-size:10px;font-weight:bold;">
<a href=$self->{home_URL}/manual/EditElement.html target=_new>Online Help</a>&nbsp;<SPAN style="font-weight:normal;">(opens in a new window)</SPAN>
</P>
HTML
  }
  print '<p><p><p>';
  print $self->{cgi}->start_multipart_form;
  if (!defined($self->{ProductLine})) {
      print <<HTML;
<P class=normal>
This page allows for real-time editing of the content of various elements on your site.  You can create content for your welcome page, your top banner panel, the navigation panel beneath the Products section, text at the top of the page for each of your product lines, and even create your own custom layout for product listings on your catalog pages.  (In order to change fonts, colors, etc. for individual elements, edit the stylesheet.)<br>
There is a size limit of 10,000 characters (enough to do 8 or so items on a splash page, depending on how much text you include, with Buy Now buttons for each).
</P>
<P class=normal>
Select which site location you wish to add or edit:
</P>
<P style="text-align:center">
HTML
      print $self->{cgi}->scrolling_list (
		-name => 'ProductLine',
                -values => [@locations],
                -size => 1,
            );
      print $self->{cgi}->submit(-name => 'page_type',
                                 -value => 'Edit Site Element'
                                );
    print '</P>';
  } else {
    for ($self->{page_type}){
      /Edit|Return/ and do {
	# get existing blurb for type and display it in form
        # check for existing blurb
        my $blurb;
        if (! ($blurb = $self->{prod_blurb})){
          (my $location = $self->{ProductLine}) =~ s/\'/\\'/g;
          $blurb = $self->{database}->get_blurb($location); 
        }
        print <<HTML;
<P style="text-align:center;font-Weight:bold;font-size:14px;">
Create/Edit $self->{ProductLine} Element
</P>
<P class=normal>
Create/edit custom content for your <b>$self->{ProductLine}</b> below.  You will be able to preview your new content on the following page so you can fix any problems before anything goes live on your site.
</P>
HTML

       
        print '<P align=center>';
        print $self->{cgi}->textarea(-name => 'prod_blurb',
                                   -default => $blurb,
                                   -rows => 20,
                                   -columns => 80,
                                   -override => 1,
	                          );
        print '<br>';
        print $self->{cgi}->submit(-name => 'page_type',
                                   -value => 'Preview Site Element'
                                  );
        # unstick prod type
        $self->{cgi}->param('ProductLine', $self->{ProductLine});
        print $self->{cgi}->hidden(-name => 'ProductLine',
                                   -value => $self->{ProductLine}
                                  );
        last;
      };
      /Preview/ and do {
	# show new blurb content in context (in a TD, that is)
	# so user can see what they've done and either commit
	# the changes or go back and tweak
        my $content_class;
        my $test_blurb = $self->{prod_blurb};
        for ($self->{ProductLine}){
          /Top Banner/ and do {
            $content_class = 'banner_panel colspan=2';
            last;
          };
          /Navigation Panel/ and do {
            $content_class = 'user_nav';
            last;
          };
	  /Catalog/ and do {
            my $img_tag = qq(<img src='' class=catalog>); 
	    map {
	     s/PROD_ID/<b>ID<\/b>/;
	     s/NAME/<b>Product Name<\/b>/;
	     s/DESCRIPTION/Product description/;
	     s/PRICE/<b>Price<\/b>/;
	     s/SALE_TAG/<SPAN class=infobox><b>Sale Price<\/b><\/SPAN><br>/;
	     s/SHIPPING/Shipping/g;
	     s/SHIP_TOTAL/<b>Total<\/b>/;
	     s/WEIGHT/<b>Weight<\/b>/;
	     s/AVAILABLE/<b>Count<\/b>/;
	     s/IMAGE_TAG/$img_tag<br><span style="font-size:10px">Photo goes here<\/span>/;
	     s/ADD_BUTTON/<p><input type=submit value="Add Item to Shopping Cart">/;
	    } $test_blurb;
	    last;
	  if ($test_blurb !~ /<p|br|t/i){
	    $test_blurb =~ s/\n/<br>/g;
	  }
	  last;
	  };
          # for Welcome and Product pages
          $content_class = 'product_blurb';
          if ($test_blurb !~ /<p|br|t/i){
            $test_blurb =~ s/\n/<br>/g;
          }
          last;
        }
        print <<HTML;
<TABLE>
<TR>
<TD colspan=2>
<b>New $self->{ProductLine}</b> element as it will appear in its actual context on the page.  If you need/want to make changes, use the Return button to go back to your edit.  To put the new content live on your site, hit Update<br>
</TD>
</TR>
<TR>
<TD class=$content_class style="border-width:1px;border-style:solid">
$test_blurb
</TD>
<TD>&nbsp;</TD>
</TR>
<TR>
<TD>
<b>HTML Sanity Check</b>&nbsp;&nbsp;This line should appear below your element.  If it's anywhere else, please go back and check your HTML to make sure you have closing tags on any tables or forms you might have created.
</TD>
</TR>
<TR>
<TD colspan=2 align=center>
HTML

        print $self->{cgi}->submit(-name => 'page_type',
                                   -value => 'Return to Site Element'
                                  );
        print $self->{cgi}->submit(-name => 'page_type',
                                   -value => 'Update Site Element'
                                  );
        # unstick prod type
        $self->{cgi}->param('ProductLine', $self->{ProductLine});
        $self->{cgi}->param('prod_blurb', $self->{prod_blurb});
        print $self->{cgi}->hidden(-name => 'ProductLine',
                                   -value => $self->{ProductLine}
                                  );
        print $self->{cgi}->hidden(-name => 'prod_blurb',
				   -value => $self->{prod_blurb}
				  );

    print <<HTML;
</TD>
</TR>
</TABLE>
HTML
	last;
      };
      /Update/ and do {
	# write blurb to database
	$self->{database}->update_blurb($self->{ProductLine},$self->{prod_blurb});
       last;
      };
    } # end page_type Edit|Preview|Update
  } # end if ProductLine else...
  print $self->{cgi}->end_form;
}

sub create_new_line {
  my $self = shift;

  # get existing lines
  my @existing = $self->{database}->get_product_lines;
  my $existing_lines = join "\n", @existing;
  $existing_lines ||= '';

  if (-e '../../manual'){
    print <<HTML;
<P class-normal style="font-size:10px;font-weight:bold;">
<a href=$self->{home_URL}/manual/ManageLines.html target=_new>Online Help</a>&nbsp;<SPAN style="font-weight:normal;">(opens in a new window)</SPAN>
</P>
HTML
  }

  if (!defined $self->{new_lines}){
    print <<HTML;
<!--
<P class=normal>
This page allows you to add new product lines for your store, remove product lines from your virtual shelves or to change the order in which your product lines will be listed in your store navigation panel.  Once you've added a new product line, you can use the Add Product option to begin adding product listings to it, or move existing products into a new line using Edit Product.
</P>
<P class=normal>
You can remove a product line without losing any product data by deleting its name from the list; while invisible to the rest of your site, a deleted product line and associated products will remain in the database and be visible in your Inventory reports.  You can restore a deleted line later by re-adding it here, and it will reappear with all product listings.  If you want to completely discontinue a product line and clear all associated data from the server, use the Discontinue Product Line option.
</P>
-->
<P class=normal>
Enter/edit your product lines below, in the order in which you want them listed, one item per line.  In order to avoid having to mess with your stylesheet, limit item names to 24 characters.
</P>
HTML
    print $self->{cgi}->start_form;
    print qq(<P style="text-align:center;">);
    print $self->{cgi}->textarea(-name => 'new_lines',
				-value => $existing_lines,
				-rows => 10,
				-columns => 24,
				);
    print '<br>';
    print $self->{cgi}->submit(-name => 'page_type',
			       -value => 'Update Product Lines'
			      );
    print '</P>';
    print $self->{cgi}->end_form;
  } else {
    print '<P class=normal>Your newly updated product lines are as follows:<br><br>';
    $self->{database}->update_prod_lines;
    my @new_lines = split /\n/, $self->{new_lines};
    my $button_order = 0;
    foreach my $new_line (@new_lines){
      next unless ($new_line =~ /\w/);
      $new_line =~ s/\W$//;
      $button_order++;
      print qq($new_line<br>);
      # add it to ProductLines table
      $self->{database}->add_line($button_order,$new_line);
    }
    print '</P>';
  } # end else

  return;
} # end create_new_line


sub discontinue_line {
  my $self = shift;
  my $discontinued_line;
  my $sth;

  if ($self->{page_type} =~ /Discontinue Product Line/){
    print <<HTML;
<p>Online help below:
<P class=normal style="font-Weight:bold;color:red">
Please use carefully!  Discontinuing a product line removes its table from the database.  It also deletes all photos for the product line from your server.  This cannot be undone with your Back button.
</P>
<P class=normal>
If you want to temporarily remove a product line from your store without losing any existing product data, just delete the product line from the list in Manage Product Lines.  The product line and product data will still show up in your inventory reports but not in your store, and you will still be able to discontinue it here later, if you like.  And, of course, if you only want to get rid of selected items, you should be using Delete Product.
</P>
<P class=normal>
For your protection, you will receive the output of all data affected by this transaction.  This will be all that remains of a product you discontinue.  Like a wet blanket in the middle of a fire, it's better than nothing.
</P>
HTML

    print $self->{cgi}->start_form;
    print <<HTML;
<P class=normal>
If you really want to get rid of an entire product line, select the name of the chosen doomed below.  To prevent major catastrophic accidents, you can only discontinue one product line at a time.
</P>
<P style="text-align:center;">
<b>Discontinue </b>
HTML

    my $lines = $self->{database}->list_stock_lines;
    print $self->{cgi}->scrolling_list(-name => 'discontinue_lines',
				       -values => [@{$lines}],
				  -size => 1,
				 );
    print <<HTML;
</P>
<P class=normal style="font-Weight:bold;text-align:center;">
Please verify that you have selected a product line you really want to discontinue.  As soon as you hit the NUKE PRODUCT LINE button below, the missile is launched and there's no calling it back.<br>
<SPAN style="color:red;">This is your final warning.</SPAN>
<br>
<SPAN style="background:red; padding-left:10px;padding-right:10px;padding-top:3px;padding-bottom:3px">
HTML
    print $self->{cgi}->submit(-name => 'page_type',
                               -value => 'NUKE PRODUCT LINE'
                              );
    print '</SPAN></P>';
    print $self->{cgi}->end_form;
    print '</P>';
  } else {	# it's  NUKE operation
    # go ahead and discontinue product(s)
    my $line = $self->{cgi}->param('discontinue_lines'); 
    #foreach my $line (@discontinued){
      print <<HTML;
<P class=normal>
Please save this page for your records.  It is all that remains of $line
<br>
<br>
HTML
      # this one's for database transactions
      ($discontinued_line = $line) =~ s/\'/\\'/g;

      # first, get photos for products in product line
      my $products = $self->{database}->list_product_line($discontinued_line);
      my $fotos_ref;

      # dump table contents so user will have a record
      print "<br>Dumping contents of $line table:<br>";
      foreach my $product (keys %{$products}){
        if ($products->{$product}{ProductFotos} !~ /^$/){
          # if there are pictures save the file names
          push @{$fotos_ref}, $products->{$product}{ProductFotos};
        }

        print "<hr><P class=normal>ITEM: <b>$products->{$product}{ProductID}&nbsp;&nbsp;$products->{$product}{ProductName}</b><br>";
	foreach my $field (keys %{$products->{$product}}){
	  print "$field: $products->{$product}{$field}<br>";
        }
        $self->{database}->delete_prod($products->{$product}{ProductID});
        print qq(Item <b>$products->{$product}{ProductID}&nbsp;&nbsp;$products->{$product}{ProductName}</b> deleted);
      }
      print '</P><P class=normal>';
      print <<HTML;
<SPAN style="color:red;">
$line has been dropped from database
</SPAN>
<hr>
<P style="margin-right:50px;margin-left:35px;">
HTML

      # now delete the photos
      foreach my $foto_line (@{$fotos_ref}){
        my @fotos = split ' ',$foto_line;
	foreach my $foto (@fotos){
          $foto =~ s/\s//g;
          unlink qq($self->{photo_db}/$foto) or warn "Couldn't unlink |$self->{photo_db}/$foto|";
          if ($foto !~ /^$/){
            print qq(<SPAN style="color:red;">$self->{photo_db}/$foto has been deleted from server</SPAN><br>);
          }
        }
      }

      # now delete its blurb
      $self->{database}->delete_blurb($discontinued_line);

      # and delete it from ProductLines list
      $self->{database}->delete_product_line($discontinued_line);

      print <<HTML;
<SPAN style="color:red;">
$line has been deleted from the Product Lines table
</SPAN>
</P>
HTML
    #}

    print <<HTML;
<P class=normal>
Product line $line has been discontinued.  There is no way to undo this change.  Please save this page for your records.  It is all that remains of $line.
HTML
  } # end else

  return;
} # end discontinue_line


# finish up customer order
# this one is pretty ugly
sub update_order {
  my $self = shift;
  my $current_order = $self->{database}->get_order($self->{order_number});

  if ($self->{shipped_date} || $self->{comments}){
    # update the orders table
    $current_order->{Comments} = $self->{comments};
    if ($self->{shipped_date}){
      $current_order->{ShipDate} = $self->{shipped_date};
    }
    # make a SQL DATE from the order's timestamp
    my ($day, $month, $year, $time) = split ' ', $current_order->{Timestamp};
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
    my $last_sale = join '/', $year, $month, $day;
    $self->{shipped_date} ||= '';
    if ($self->{shipped_date} =~ /\d-\d/i){
      # order has shipped, so update product sales and
      # products tables
      my @cart_list = split "\n", $current_order->{CartContents};
      foreach my $item (@cart_list){
        # assemble a hash of useful information
        my $sale_data = $self->{database}->load_data($item, $last_sale, $self->{shipped_date}, $current_order->{OrderNumber});

        # update ProductSales
        $self->{database}->update_product_sales($sale_data);
        # update Products table
        $self->{database}->update_products_table($sale_data);
      } # foreach item
    } else {
      # don't want a sale amount for a cancelled order in the
      # Orders table
      $current_order->{SaleTotal} = 0;
    }
    # replace record in Orders table
    $self->{database}->update_orders_table($current_order);
#    my $next_order = $current_order->{OrderNumber}+1;
    print <<HTML;
<P class=normal>
Record for order number <b>$current_order->{OrderNumber}</b> has been updated.
</P>
HTML
  } #else {
  my $order_number = $self->{order_number};
  $order_number ||= $current_order->{OrderNumber};
  # we have, at best, an order number
  print $self->{cgi}->start_form;
  # if we have an order number, process it
  #  get order from database
  if ($order_number){
      my $order_ref = $self->{database}->get_order($order_number);
      if ($order_ref){
        my $next_order = 0;
        if ($self->{database}->get_order($order_ref->{OrderNumber} + 1)){
	  $next_order=$order_ref->{OrderNumber} + 1;
        }
	my $previous_order = $order_ref->{OrderNumber} - 1;
      # print a form showing order with shipped_date and
      # comments fields
      print <<HTML;
<TABLE align=center width=500 cellspacing=0 cellpadding=0>
<TR>
<TD align=center>
<a href=$self->{admin_CGI}?page_type=Update%20Order&order_number=$previous_order class=reports>Go to previous order</a>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
HTML
      if ($next_order){
	print qq(<a href=$self->{admin_CGI}?page_type=Update%20Order&order_number=$next_order class=reports>Go to next order</a>);
      }
      print <<HTML;
<P>&nbsp;</P>
</TD>
</TR>
<TR>
<TD align=right>
<b>Order Number: </b> $order_ref->{OrderNumber}<br>
<b>Order Date: </b> $order_ref->{Timestamp}
HTML

      if ($order_ref->{ShipDate}){
        print "<br><b>Date Shipped:</b> $order_ref->{ShipDate}";
      }
      print <<HTML;
</TD>
</TR>
<TR>
<TD>
<P class=normal>
<b>Order Items:</b><br>
HTML

      my @items = split "\n", $order_ref->{CartContents};
      my $subtotal;
      foreach my $item (@items){
        my ($ProductID,$ProductName,$price,$Shipping,$quantity) = split "\t", $item;
        $price = sprintf "%1.2f", $price;
        my $cost = sprintf "%1.2f", ($price * $quantity);
        print "$quantity x $ProductName \@ $self->{currency}$price = $self->{currency}$cost<br>";
        $subtotal += $price * $quantity;
      }
      my $total_Shipping = $order_ref->{Shipping};
      $total_Shipping ||= 0;
      $total_Shipping = sprintf "%1.2f", $total_Shipping;
      $subtotal = sprintf "%1.2f", $subtotal;
      my $sales_tax = $order_ref->{SalesTax};
      $sales_tax ||= '0';
      $sales_tax = sprintf "%1.2f", $sales_tax;
      my $total_sale = sprintf "%1.2f", ($order_ref->{SaleTotal} + $sales_tax + $total_Shipping);
      print <<HTML;
<b>Subtotal:</b>  $subtotal<br>
<b>Sales Tax:</b>  $sales_tax<br>
<b>Shipping:</b>  $total_Shipping<br>
<b>Total: </b> $self->{currency}$total_sale
</P>
</TD>
</TR>
<TR>
<TD>
<P class=normal>
HTML

      $self->{cgi}->param('shipped_date', $self->{shipped_date});
#      if ($order_ref->{ShipDate} !~ /\d-\d/){
        print 'Enter date shipped as YYYY-MM-DD<br> (e.g.,  15 March 2007 = 2007-03-15) or some indicator of your choice for backorders, canceled orders, etc.:<br> ';
        print $self->{cgi}->textfield(-name => 'shipped_date',
	 			    -default => $order_ref->{ShipDate},
				    -size => 20,
				    -maxlength => 20
				   );
#      }
      print '<br>';
      print 'Comments regarding this order:<br>';
      print $self->{cgi}->textarea(-name => 'comments',
				 -default => $order_ref->{Comments},
				 -rows => 10,
				 -columns => 50,
				 -override => 1
				);
      print '<br>';
      $self->{cgi}->param('order_number', $order_ref->{order_number});
      print $self->{cgi}->hidden(-name => 'order_number',
                               -value => $order_ref->{order_number}
                              );
      print $self->{cgi}->submit(-name => 'page_type',
			       -value => 'Update Order'
			      );
      print <<HTML;
</P>
</TD>
</TR>
</TABLE>
HTML
      } else {
	print qq(Order Number $self->{order_number} is not in the database);
      }
    } else {	
      # we don't have anything
      # print a form to input an order number
      print <<HTML;
<P class=normal>
Here is where you update customer orders.  You can add a shipped date for a completed order, as well as comments regarding an order.
<br><br>
Enter the order number you wish to update: 
HTML
      print $self->{cgi}->textfield(-name => 'order_number',
				  -value => '',
				  -size => 6,
				  -maxlength => 6,
				 );
      print $self->{cgi}->submit(-name => 'page_type',
			       -value => 'Update Order'
			      );

      print '</P>';
    } # end else (if no order number)
    print $self->{cgi}->end_form;
#  } # end else (if no shipped date or comment)
  return;
} # end update_order 

sub edit_stylesheet {
  my $self = shift;
  my $css_file = qq(../../$self->{stylesheet});
  if (-e '../../manual'){
    print <<HTML;
<P class-normal style="font-size:10px;font-weight:bold;">
<a href=$self->{home_URL}/manual/EditStylesheet.html target=_new>Online Help</a>&nbsp;<SPAN style="font-weight:normal;">(opens in a new window)</SPAN>
</P>
HTML
  }

  if (! $self->{new_style}) {
    my $stylesheet;
    open STYLES, $css_file or warn "Can't open $css_file: $!\n";
    while (<STYLES>) {
      $stylesheet .= $_;
    }
    close STYLES;
    print $self->{cgi}->start_form;
    print '<P align=center>';
    print $self->{cgi}->textarea (-name => 'new_style',
				  -default => $stylesheet,
				  -rows => 20,
				  -columns => 65,
				  -override => 1,
			         );
    print '<br>';
    print $self->{cgi}->submit (-name => 'page_type',
			        -value => 'Update Stylesheet',
  			       );
    print '</P>';
    print $self->{cgi}->end_form;
  } else {
  # write updated stylesheet file
    open STYLES, ">$css_file" or warn "Can't open $css_file: $!\n";
    print STYLES $self->{new_style};
    close STYLES;

    print <<HTML;
<P class=normal>
Your stylesheet has been updated.  Changes should take effect with the next page you load.
</P>
HTML
  }
}

sub cart_patrol {
  use SB_Cesto;

  my $self = shift;
  my $bag_boy = SB_Cesto->nuevo(cgi => $self->{cgi},
                                 dbh => $self->{dbh}
                                );
  $bag_boy->police_carts($self->{cart_expire});
}


# and we're outta here!
1;
