package GD::OrgChart;


# Copyright 2002, Gary A. Algier.  All rights reserved.  This module is
# free software; you can redistribute it or modify it under the same
# terms as Perl itself.

use 5.006;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use GD::OrgChart ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);
our $VERSION = '0.01';

use GD;

use constant PARAMS => {
	boxbgcolor => [255,255,255],
	boxfgcolor => [0,0,0],
	boxtextcolor => [255,0,0],
	boxtop => 4,
	boxbottom => 4,
	boxleft => 4,
	boxright => 4,
	boxborder => 1,
	linespacing => 4,
	size => 12,
	font => "/dev/null",
	top => 10,
	bottom => 10,
	left => 10,
	right => 10,
	horzspacing => 20,
	vertspacing => 20,
	linewidth => 1,
	linecolor => [0,0,255],
	depth => 0,
	debug => 0,
};

our %PARAMS = %{&PARAMS};

END { }       # module clean-up code here (global destructor)

sub new
{
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	$self->{image} = undef;
	$self->{adorn} = sub {};
	$self->{params} = { %PARAMS };
	if (@_ > 0 && ref($_[0]) eq "HASH") {
		my $p = shift;
		@{$self->{params}}{keys %$p} = values %$p;
	}
	bless($self,$class);
	return $self;
}

sub image
{
	my $self = shift;

	if (@_) {
		$self->{image} = shift;
	}
	return $self->{image};
}

sub adorn
{
	my $self = shift;

	if (@_) {
		$self->{adorn} = shift;
	}
	return $self->{adorn};
}


# BoundTree
#	usage:
#		$chart->BoundTree($node,{ params...})
sub BoundTree
{
	my $self = shift;
	my $node = shift;
	my %params = %{$self->{params}};

	if (@_ == 1 && ref($_[0]) eq "HASH") {
		my $p = shift;
		@params{keys %$p} = values %$p;
	}

# XXX: should we barf on left over arguments?

	return $self->_BoundTree($node,
		$params{depth} > 0 ? $params{depth} : 0,
		0,%params);
}

sub _BoundTree
{
	my $self = shift;
	my $node = shift;
	my $maxdepth = shift;;
	my $curdepth = 1 + shift;;
	my %params = @_;

	if ($node->{params} && ref($node->{params}) eq "HASH") {
		my $p = $node->{params};
		@params{keys %$p} = values %$p;
	}

	my (@box);
	my (@tree,$treeleft,$treeright,$treetop,$treebottom);

	@tree = @box = $self->BoundBox($node,\%params);
	$node->{BoxBounds} = [ @box ];
	$node->{BoxSize} = sprintf("%dx%d",height(@box),width(@box));
	$treetop = top(@tree);
	$treeleft = left(@tree);
	$treebottom = bottom(@tree);
	$treeright = right(@tree);

	# if no subs or we are deep enough, we are done.
	if (!defined($node->{subs}) || ($maxdepth && $curdepth >= $maxdepth)) {
		$node->{TreeBounds} = [ @tree ];
		$node->{TreeSize} = sprintf("%dx%d",height(@tree),width(@tree));
		return @tree;
	}

	my $totalwidth = 0;
	my $highest = 0;
	foreach my $sub (@{$node->{subs}}) {
		my @sub = $self->_BoundTree($sub,$maxdepth,$curdepth,%params);
		$totalwidth += width(@sub);
		$highest = max($highest,height(@sub));
	}
	$totalwidth += $params{horzspacing} * (scalar @{$node->{subs}} - 1);
	$treebottom += $params{vertspacing} * 2 + $highest;
	if (width(@box) < $totalwidth) {
		my $diff = $totalwidth - width(@box);
		$treeleft -= firsthalf($diff);
		$treeright += secondhalf($diff);
	}

	@tree = ($treeleft,$treebottom,$treeright,$treetop);

	$node->{TreeBounds} = [ @tree ];
	$node->{TreeSize} = sprintf("%dx%d",height(@tree),width(@tree));
	return @tree;
}


# DrawTree:
#	usage:
#		$chart->DrawTree($node,{ params ...});
sub DrawTree
{
	my $self = shift;
	my $node = shift;
	my %params = %{$self->{params}};

	my ($x,$y);

	if (@_ == 1 && ref($_[0]) eq "HASH") {
		my $p = shift;
		@params{keys %$p} = values %$p;
	}

# XXX: If there are arguments left we should produce a warning.

	# if this has not been done, do it now:
	if (!defined($node->{TreeBounds})) {
		$self->BoundTree($node,%params);
	}

	if (!defined($self->{image})) {
		my @b = @{$node->{TreeBounds}};
		my $w = width(@b) + $params{left} + $params{right};
		my $h = height(@b) + $params{top} + $params{bottom};
		$self->{image} = new GD::Image($w,$h);
	}

	if (!defined($params{x}) || !defined($params{y})) {
		my $treewidth = width(@{$node->{TreeBounds}})
			+ $params{left} + $params{right};
		my $boxheight = height(@{$node->{BoxBounds}});
		$x = firsthalf($treewidth);
		$y = firsthalf($boxheight) + $params{top};
	}

	return $self->_DrawTree($node,$x,$y,
		$params{depth} > 0 ? $params{depth} : 0,
		0,%params);
}

sub _DrawTree
{
	my $self = shift;
	my $node = shift;
	my $x = shift;
	my $y = shift;
	my $maxdepth = shift;
	my $curdepth = 1 + shift;
	my %params = @_;

	if ($node->{params} && ref($node->{params}) eq "HASH") {
		my $p = $node->{params};
		@params{keys %$p} = values %$p;
	}

	my (@box);
	my (@tree,$treeleft,$treeright,$treetop,$treebottom);
	my ($temp,$junction,$subtop,$linecolor);

	# draw our box
	@box = $self->DrawBox($node,$x,$y,\%params);
	$node->{BoxBounds} = [ @box ];
	$node->{BoxSize} = sprintf("%dx%d",height(@box),width(@box));

	@tree = @box;
	$treetop = top(@tree);
	$treeleft = left(@tree);
	$treebottom = bottom(@tree);
	$treeright = right(@tree);
	$node->{TreeBounds} = [ @tree ];
	$node->{TreeSize} = sprintf("%dx%d",height(@tree),width(@tree));

	# if no subs or we are deep enough, we are done.
	if (!defined($node->{subs}) || ($maxdepth && $curdepth >= $maxdepth)) {
		$node->{TreeBounds} = [ @tree ];
		$node->{TreeSize} = sprintf("%dx%d",height(@tree),width(@tree));
		return @tree;
	}

	# we have subs, so let us draw some lines
	$linecolor = $self->{image}->colorAllocate(@{$params{linecolor}});

	# this is the line from the bottom of our box to the horizontal line
	$temp = $y + secondhalf(height(@box));
	$junction = $temp + $params{vertspacing};
	$subtop = $junction + $params{vertspacing};
	$self->{image}->line($x,$temp,$x,$junction,$linecolor);

	$treebottom = $junction;

	my @widths = map {
			defined($_->{TreeBounds})
				? width(@{$_->{TreeBounds}})
				: ();
		} @{$node->{subs}};
	my $subx = $x;

	if (@widths > 1) {
		my $totalwidth = 0;
		# there is more than one sub, so we need a horizontal line
		my $left = $widths[0];
		my $right = $widths[@widths-1];
		for my $w (@widths) {
			$totalwidth += $w;
		}
		$totalwidth += $params{horzspacing} * (@widths - 1);

		# the horizontal line is not centered, the tree below the
		# line is centered.
		$subx = $x - firsthalf($totalwidth) + firsthalf($left);
		$temp = $x + secondhalf($totalwidth) - secondhalf($right);

		$self->{image}->line($subx,$junction,
			$temp,$junction,$linecolor);
		$treeleft = min($treeleft,$x - firsthalf($totalwidth));
		$treeright = max($treeleft,$x + secondhalf($totalwidth));
	}

	# draw lines down to the sub trees and draw the trees
	for my $sub (@{$node->{subs}}) {
		my $width = shift @widths;
		$self->{image}->line($subx,$junction,
			$subx,$junction+$params{vertspacing},$linecolor);
		$temp = $junction + $params{vertspacing}
			+ firsthalf(height(@{$sub->{BoxBounds}}));
		my @sub = $self->_DrawTree($sub,$subx,$temp,
			$maxdepth,$curdepth,%params);
		$treeleft = min($treeleft,left(@sub));
		$treeright = max($treeright,right(@sub));
		$treebottom = max($treebottom,bottom(@sub));
		if (@widths) {
			$subx += secondhalf($width);
			$subx += $params{horzspacing};
			$subx += firsthalf($widths[0]);
		}
	}

	@tree = ($treeleft,$treebottom,$treeright,$treetop);
	$node->{TreeBounds} = [ @tree ];
	$node->{TreeSize} = sprintf("%dx%d",height(@tree),width(@tree));
	return @tree;
}


sub BoundBox
{
	my $self = shift;

	my $node = shift;

	my %params = %{$self->{params}};
	if (@_ == 1) {
		my $p = shift;
		@params{keys %$p} = values %$p;
	}

	if ($node->{params} && ref($node->{params}) eq "HASH") {
		my $p = $node->{params};
		@params{keys %$p} = values %$p;
	}

	my ($width,$height);
	$width = $height = 0;

	if ($params{size} > 0 && defined($node->{text})) {
		my @text = split("\n",$node->{text});
		for my $text (@text) {
			my @bounds = rebound(GD::Image->stringFT(0,
					$params{font},$params{size},
					0,0,0,$text));
			$width = max($width,width(@bounds));
			$height += height(@bounds);
		}
		$height += (@text - 1) * $params{linespacing};
	}

	$width += $params{boxleft} + $params{boxright}
		+ 2 * $params{boxborder};
	$height += $params{boxtop} + $params{boxbottom}
		+ 2 * $params{boxborder};

	my ($left,$bottom,$right,$top);
	$left = -firsthalf($width);
	$right = $left + $width;
	$top = -firsthalf($height);
	$bottom = $top + $height;

	my @box = ($left,$bottom,$right,$top);
	return @box;
}


sub DrawBox
{
	my $self = shift;

	my $node = shift;

	my $x = shift;
	my $y = shift;

	my %params = %{$self->{params}};
	if (@_ == 1) {
		my $p = shift;
		@params{keys %$p} = values %$p;
	}

	if ($node->{params} && ref($node->{params}) eq "HASH") {
		my $p = $node->{params};
		@params{keys %$p} = values %$p;
	}

	my ($width,$height,@width,@height);
	$width = $height = 0;

	if ($params{size} > 0 && defined($node->{text})) {
		my @text = split("\n",$node->{text});
		for my $text (@text) {
			my @bounds = rebound(GD::Image->stringFT(0,
					$params{font},$params{size},
					0,0,0,$text));
			push @width,width(@bounds);
			push @height,height(@bounds);
			$width = max($width,width(@bounds));
			$height += height(@bounds);
		}
		$height += (@text - 1) * $params{linespacing};
	}

	$width += $params{boxleft} + $params{boxright}
		+ 2 * $params{boxborder};
	$height += $params{boxtop} + $params{boxbottom}
		+ 2 * $params{boxborder};

	my ($left,$bottom,$right,$top);
	$left = $x - firsthalf($width);
	$right = $left + $width;
	$top = $y - firsthalf($height);
	$bottom = $top + $height;

	my $bgcolor = $self->{image}->colorAllocate(@{$params{boxbgcolor}});
	my $fgcolor = $self->{image}->colorAllocate(@{$params{boxfgcolor}});
	my $textcolor = $self->{image}->colorAllocate(@{$params{boxtextcolor}});

	# make a "black" rectangle with a "white" fill
	$self->{image}->filledRectangle($left,$top,$right,$bottom,$fgcolor);
	$self->{image}->filledRectangle($left+$params{boxborder},
		$top+$params{boxborder},
		$right-$params{boxborder},
		$bottom-$params{boxborder},
		$bgcolor);

	if ($params{size} > 0 && defined($node->{text})) {
		my $ytemp = $top + $params{boxborder} + $params{boxtop};
		my @text = split("\n",$node->{text});
		for my $text (@text) {
			my $h = shift @height;
			$self->{image}->stringFT($textcolor,
					$params{font},$params{size},
					0,$x - firsthalf(shift @width),
					$ytemp + $h,$text);
			$ytemp += $h + $params{linespacing};
		}
	}

	my @box = ($left,$bottom,$right,$top);
	$self->{adorn}($self,$node,$x,$y,\@box);
	return @box;
}


# The GD package returns bounds as in:
#	(left,bottom,right,bottom,right,top,left,top)
# This is redundant.  I use the Postscript idea of:
#	(left,bottom,right,top)
# This function does the conversion
sub rebound
{
	if (@_ == 8) {
		 return @_[0,1,4,5];
	}
	else {
		return (0,0,0,0);
	}
}

# in many cases we need two different
# "half" values such that the sum equals the whole.
sub firsthalf
{
	return int($_[0] / 2);
}

sub secondhalf
{
	return $_[0] - int($_[0] / 2);
}

sub top
{
	return $_[3];
}
sub bottom
{
	return $_[1];
}
sub left
{
	return $_[0];
}
sub right
{
	return $_[2];
}
sub width
{
	return abs($_[0] - $_[2]);
}
sub height
{
	return abs($_[1] - $_[3]);
}
sub min
{
	my $min = shift;
	my $x;

	while (@_) {
		$x = shift;
		$min = $x if ($x < $min);
	}
	return $min;
}
sub max
{
	my $max = shift;
	my $x;

	while (@_) {
		$x = shift;
		$max = $x if ($x > $max);
	}
	return $max;
}

1;
__END__

# Below is stub documentation for your module. You better edit it!

=head1 NAME

GD::OrgChart - Perl extension for generating personel organization charts

=head1 SYNOPSIS

  # This bit of code will display a simple orgchart using the
  # Imagemagick "display" command

  use GD::OrgChart;
  use constant FONT => "/some/path/to/truetype/fonts/times.ttf";
  use IO::Pipe;

  our $COMPANY;

  # put data into $COMPANY such that it looks like:
  $COMPANY =
    { text => "Gary\nHome Owner", subs => [
      { text => "Tex\nVice President, Back Yard Security", subs => [
        { text => "Ophelia\nGate Watcher" },
        { text => "Cinnamon\nDeck Sitter" },
      ]},
      { text => "Dudley\nVice President, Front Yard Security", subs => [
        { text => "Jax\nBay Window Watcher" },
        { text => "Maisie\nDoor Watcher" },
      ]},
    ]};

  our $chart = new GD::OrgChart({ size => 12, font => FONT });
  $chart->DrawTree($COMPANY);

  our $fh = new IO::Pipe;
  if (!$fh || !($fh->writer("display -"))) {
    # error
    ...
  }
  binmode $fh;	# just in case

  our $image = $chart->image;
  $fh->print($image->png);
  $fh->close();

=head1 DESCRIPTION

=head1 AUTHOR

Gary A. Algier, E<lt>gaa@magpage.comE<gt>

=head1 SEE ALSO

L<perl>.

=cut
