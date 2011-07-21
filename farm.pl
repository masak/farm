class Game {
    has @.p = {};
    has &!fd;
    has &!wd;
    has @.e;

    method play_round() {
        my ($a1, $a2) = &!fd(), &!wd();
        my %stock = @!p[0].list;
        %stock{$_}++ for $a1, $a2;
        (my %to_transfer){$_} = %stock{$_} div 2
            if %stock{$_} div 2
            for $a1, $a2;
        push @.e, {
            type    => "transfer",
            from    => "stock",
            to      => "player 1",
            animals => %to_transfer,
        } if %to_transfer;
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

{
    my $game = Game.new(fd => { <rabbit> }, wd => { <sheep> });
    $game.play_round();
    is_deeply $game.e, [], "rolling rabbit/sheep gives you nothing";
}

{
    my $game = Game.new(p => ({ rabbit => 2 }),
                        fd => { <rabbit> }, wd => { <sheep> });
    $game.play_round();
    is_deeply $game.e, [{
        type    => "transfer",
        from    => "stock",
        to      => "player 1",
        animals => { rabbit => 1 },
    }], "rolling rabbit/sheep if you already have 2 rabbits";
}
