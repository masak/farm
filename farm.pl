class Game {
    has @.e;

    method play_round() {
        push @.e, {
            type    => "transfer",
            from    => "stock",
            to      => "player 1",
            animals => { rabbit => 1 },
        };
    }
}

use Test;

{
    my $game = Game.new(fd => { <rabbit> }, wd => { <rabbit> });
    $game.play_round();
    is_deeply $game.e, [{
        type    => "transfer",
        from    => "stock",
        to      => "player 1",
        animals => { rabbit => 1 },
    }], "rolling two rabbits gives you a rabbit";
}
