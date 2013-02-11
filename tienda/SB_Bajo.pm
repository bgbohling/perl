package SB_Bajo;

# Base class for SB_Tienda* modules

# SB_Bajo.pm Copyright (C) 2006-2007 Bill G. Bohling
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
# 51 Franklin Street, Fifth Floor
# Boston, MA  02110-1301, USA.

# SB_Bajo is the base class for all SB_Tienda* modules.  It
# provides an inheritable new() and a basic init that
# defines site-wide constants like paths and property types,
# as well as obtaining parameters from CGI.  In addition, this
# is the class that displays the page header and navigation 
# bar.  Cosmetics are handled in the stylesheet, there should
# be nothing to be done that way in here.
#
# To use this module, include the following lines in your
# derived class (uncommented, of course):
#
#	# this line lets you call SB_Bajo's init()
#	@ISA = qw(SB_Bajo);
#	# this line lets you use SB_Bajo's methods
#	use SB_Bajo;
#
# The init() method in your derived class then goes like this
# (if nothing else, you do need to write an init for your
# derived class that calls bajo_init:
#
# sub init {
#	my $self = shift;
#
#	# first, call SB_Bajo's init
#	# (uses a unique name to avoid warnings about init()
#	# being redefined by calling module
#	$self->SUPER::bajo_init;
#
#	# add anything else your module needs
#	$self->{foo} = 'bar';
#	$self->{bar} = 'foo';
#	# etc.
# } # end init
#
#

# make sure we play well with others
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(new bajo_init print_header print_navbar footer);

use strict;
use CGI  qw/:standard:/;
use DBI;
use SB_TiendaDB;


sub new {
  my $type = shift;
  my $self = {};
  bless $self, $type;
  $self->{config_file} = shift;
  # use the calling class's init
  $self->init;
  return $self;
}

# an init to handle things that are common to every page
# this should be called by the calling module
sub bajo_init {
  my $self = shift;

  my ($package, $filename, $line) = caller;
  $self->{caller} = $package;

  # get the configuration
  open CONFIG, $self->{config_file} or warn "Couldn't open config file $self->{config_file}: $!";
  while (<CONFIG>){
    next if (/^#|^\s*$/);
    chomp;
    s/\s*=\s*/=/;
    s/\s*$//;
    my ($key, $value) = split '=', $_;
    $self->{$key} = $value;
  } 
  close CONFIG;


# what's our stylesheet?
  $self->{styles} = qq($self->{home_URL}/$self->{stylesheet});

# database connection
  $self->{dbh} = DBI->connect($self->{db_connect}, $self->{db_user}, $self->{db_clave}) or warn "No database connection:  Make sure your database connection information is correct in your config file and that DBI.pm is installed on your host.";
  $self->{database} = SB_TiendaDB->new($self->{dbh});
  $self->{cgi} = new CGI;
  $self->{user_agent} = $ENV{HTTP_USER_AGENT};


  # what are we selling?
  # get the product lines list
  if ($package =~ /tienda/i){
    @{$self->{products}} = $self->{database}->get_product_lines;
  }
  # paths for CGIs to use
  # home
  $self->{doc_root} = $ENV{DOCUMENT_ROOT};
  # set full path for certificates (from config file)
#  $self->{my_private_key} = qq($self->{doc_root}/$self->{my_private_key});
#  $self->{my_public_cert} = qq($self->{doc_root}/$self->{my_public_cert});
#  $self->{paypal_cert} = qq($self->{doc_root}/$self->{paypal_cert});
  # for photo storage
  $self->{photo_db} = qq($self->{doc_root}/$self->{photo_path});
  # and photo retrieval
  $self->{photo_URL} = "$self->{home_URL}/$self->{photo_dir}";


  $self->{cgi} = new CGI;

  # get CGI params
  $self->{cgi_params} = $self->{cgi}->Vars;
  my $key;
#warn '*************** cgi params in ********************';
  foreach $key (keys %{$self->{cgi_params}}){
    $self->{$key} = $self->{cgi_params}{$key};
#warn "$key:  |$self->{$key}|";
  }
#warn '************* end cgi params *********************';

  $self->{page_header} = $self->process_page_type;
  $self->{page_header} ||= 'Store Front'; 
  # unstick
  $self->{cgi}->param('return_to', $self->{return_to});

  return $self;
} # end init

sub process_page_type {
  my $self = shift;
  my $page_type = $self->{page_type};
  if ($self->{cart_action}){
    $page_type = $self->{cart_action};
  }
  if (!defined $page_type){
    for ($self->{caller}){
      /SB_Arregla/ and do {
	$page_type = q(Manager's Office);
	last;
      };
      $page_type = 'Store Front';
      last;
    }
    return;
  } 
    for ($page_type) {
      !/Add Item|Keep Shopping|Cart|Check Out|Invoice|Complete|Back To/ and do {
        $self->{return_to} = $page_type;
        last;
      };
      /Add Item|Update Cart|Check Out|Invoice|Complete|Back To/ and do {
        $self->{return_to} = $self->{return_to};
        last;
      };
      /Keep Shopping/ and do {
        $page_type = $self->{return_to};
        last;
      };
      /Store Front/ and do {
        $page_type = 'Store Front';
        last;
      };
      $self->{return_to} = $self->{return_to};
      last;
    }
  return $page_type;
}

sub print_header {
  my $self = shift;
 
  if ($self->{caller} =~ /SB_Arregla/){
    $self->{title} = qq($self->{title} Office);
  }
  if ($self->{new_shopper}){
    print $self->{cgi}->header(-cookie => $self->{new_shopper});
  } else {
    print $self->{cgi}->header();
  }
  print $self->{cgi}->start_html (-title => $self->{title},
                          	  -style => {'src' => $self->{styles} },
                          	 );
  if ($self->{user_agent} !~ /IE/){
    print '<DIV class=banner_panel>';
  } else {
  print <<HTML;
<TABLE class=outer cellspacing=0 align=center>
<TR>
<TD class=banner_panel colspan=2>
HTML
  }

  # check for user-specified top banner
  my $custom_banner = $self->{database}->get_blurb('Top Banner');

  if ($custom_banner){
    $custom_banner = $self->map_user_content($custom_banner);
    # let user hide store navigation on pages
    # that don't need it
    if (($self->{page_type} =~ /Detail|Invoice|Thank You/) || ($self->{caller} =~ /Arregla/)){
      map { s/<HIDE>/<!--/;
	    s/<\/HIDE>/-->/;
          } $custom_banner
    }

    print $custom_banner;
  } else {
    print <<HTML;
<SPAN class=store_name>
$self->{title}
</SPAN>
<br>
<SPAN class=page_type>
$self->{page_header}
</SPAN>
HTML
    if ($self->{page_type} =~ /Detail|Edit Product/){
      my $name = $self->{prod_name} || $self->{edit_prod_id} || '';
      print <<HTML;
<br>
<SPAN class=page_type>
$name
</SPAN>
HTML
    }
  }

  if ($self->{user_agent} !~ /IE/){
    print '</DIV>';
  } else {
  print <<HTML;
</TD>
</TR>
<TR>
HTML
  }

} # end print_header

sub print_navbar {
  my $self=shift;
  my $nav_title;

  for ($self->{caller}) {
    /SB_Arregla/ and do {
      $nav_title = 'Options';
      last;
    };
    /SB_Tienda/ and do {
      $nav_title = 'Products';
    };
  }

  if ($self->{user_agent} !~ /IE/){
    print '<DIV class=navbar>';
  } else {
    print <<HTML;
<TD class=nav_panel valign=top>
<TABLE class=navbar cellpadding=0 cellspacing=0>
<TR>
<TD class=nav_buttons>
HTML
  }

  # print the buttons
  # don't provide navigation on Details pages, as they open
  # in new windows, and printer pages don't need it
  if ($self->{page_type} !~ /Detail/) {
    # check for user-defined nav panel
    my $user_nav = $self->{database}->get_blurb('Navigation Panel');
    if (($self->{caller} =~ /Arregla/) || (! $user_nav)){print $self->{cgi}->start_form};
    # use user-defined navigation for store pages, if available
    if (($user_nav) && ($self->{caller} !~ /Arregla/)){
      # first, handle some special characters so we can
      # pass CGI parameters in links
      $user_nav = $self->map_user_content($user_nav);
      print $user_nav;
    } else {
      # use default navigation scheme
      print <<HTML;
<P class=products align=left>
$nav_title:
</P>
<P class=nav_buttons>
HTML
      foreach my $button (@{$self->{nav_buttons}}){
        print $self->{cgi}->submit(-name => 'page_type',
	 			   -value => $button,
				  );
        print '<br>';
      }
      # check for a shopping cart
      my $shopper = $self->{cgi}->cookie('cesto');
      if ($self->{caller} !~ /Arregla/ && $self->{database}->got_cart($shopper) && ($self->{page_type} !~ /Add Item|Cart|Thank You/)){
        print '<br>';
        print $self->{cgi}->submit(-name => 'page_type',
                                   -value => 'My Cart',
                                  );
      }
    }
      print $self->{cgi}->hidden(-name => 'return_to',
                                 -value => $self->{return_to}
				);
      if (($self->{caller} =~ /SB_Tienda/) && (! $user_nav)){
        print '<br>';
        print $self->{cgi}->submit(-name => 'page_type',
                                   -value => 'Store Front',
                                  );
        print '<br>';
      }

    print '</P>';

    print '<P class=nav_buttons>';
    if ($self->{caller} =~ /SB_Arregla/){
      my $manual_URL = '';
      if (-e '../../manual'){
	$manual_URL = qq(<br><a href=$self->{home_URL}/manual/Management.html target=_new class=catalog><b>Owner's Manual</b></a><br><span style="font-size:10px;">(Opens in a new window)</span>);
      }
      print <<HTML;
<a href=../$self->{store_CGI} target=_new class=catalog><b>Go to Store</b></a>
<br>
<span style="font-size:10px;">(Opens in a new window)</span><br>
$manual_URL
HTML

    }
    print '</P>';
    print $self->{cgi}->end_form;

    if ($self->{user_agent} !~ /IE/){
      print '</DIV>';
    } else {
      print <<HTML;
</TD>
</TR>
</TABLE>
</TD>
HTML
    }
  
  } # end if ! Detail or Printer-friendly

} # end print_navbar


sub show_content {
  # stub for a method that absolutely has to be handled
  # by the calling module, since this is the interactive
  # part of the page
  print 'Write the show_content method for your calling class';
}

# map actual values to user-defined content in the navbar
# and top banner
sub map_user_content {
  my $self = shift;
  my $user_content = shift;
  my $shopper = $self->{cgi}->cookie('cesto') || '';
  $self->{prod_name} ||= '';
  my $bag = $self->{database}->got_cart($shopper);
  my $return_to = $self->{return_to} || 'Store+Front';
  $return_to =~ s/\s/%20/g;

    map { s/MY_CGI/$self->{store_CGI}/g;
	  s/STORE_NAME/$self->{title}/;
	  s/PAGE_TYPE/$self->{page_type}/;
          s/PROD_NAME/$self->{prod_name}/;
          s/<START_FORM>/<FORM>/g;
          s/<END_FORM>/<\/FORM>/g;
          s/RETURN_TO/$return_to/g;
        } $user_content;
    # hide the shopping cart button unless there's somthing in it
    if (! $bag){
      $user_content =~ s/<CART>.*<\/CART>//;
    }
  return $user_content;
}

sub footer {
  my $self = shift;
  print $self->{cgi}->end_html;
}

1;
