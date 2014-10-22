use Test;
BEGIN { plan tests => 1 };
use GD::OrgChart;

  use IO::File;

  our $NAME = "text-home";

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

  our $FONT = `pwd`;
  chomp $FONT;
  $FONT .= "/doggy.ttf";

  our $chart = GD::OrgChart->new({ size => 12, font => $FONT });
  $chart->DrawTree($COMPANY);

  our $fh = IO::File->new("t/$NAME.tmp", "w");
  binmode $fh;	# just in case

  our $image = $chart->image;
  $fh->print($image->png);
  $fh->close();

  our $status = system "cmp", "-s", "t/$NAME.png", "t/$NAME.tmp";

ok($status == 0);
