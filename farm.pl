class Game {
    method play_round() {
    }
}

use Test;

{
    my @e;
    my $game = Game.new(fd => { <rabbit> }, wd => { <rabbit> }, e => @e);
    $game.play_round();
    is_deeply @e, [{
        type    => "transfer",
        from    => "stock",
        to      => "player 1",
        animals => { rabbit => 1 },
    }];
}
