class Game {
    has %!p;
    has &!fd;
    has &!wd;
    has @.e;
    has $!cp;

    submethod BUILD(:%!p, :&!fd, :&!wd, :@!e, :$!cp = 'player_1') {
        %!p<stock> //= hash <rabbit sheep pig cow horse small_dog big_dog> Z=>
                            (    60,   24, 20, 12,    6,        4,      2);
        &!fd //= { ('rabbit' xx 6, <sheep pig> xx 2, 'horse', 'fox').roll };
        &!wd //= { ('rabbit' xx 6, 'sheep' xx 3, 'pig', 'cow', 'wolf').roll };
    }

    method transfer($from, $to, %animals) {
        for %animals.kv -> $animal, $amount {
            %!p{$from}{$animal} -= $amount;
            %!p{$to  }{$animal} += $amount;
        }
        push @.e, { :type<transfer>, :$from, :$to, :%animals };
    }

    method play_round() {
        my ($a1, $a2) = &!fd(), &!wd();
        if $a2 eq 'wolf' {
            if %!p{$!cp}<big_dog> {
                $.transfer($!cp, "stock", { big_dog => 1 });
            }
            else {
                (my %to_transfer){$_} = %!p{$!cp}{$_}
                    if %!p{$!cp}{$_} for <rabbit sheep pig cow>;
                $.transfer($!cp, "stock", %to_transfer)
                    if %to_transfer;
            }
        }
        if $a1 eq 'fox' {
            if %!p{$!cp}<small_dog> {
                $.transfer($!cp, "stock", { small_dog => 1 });
            }
            else {
                $.transfer($!cp, "stock",
                           { rabbit => %!p{$!cp}<rabbit> })
                    if %!p{$!cp}<rabbit>;
            }
        }

        my %stock = %!p{$!cp} // {};
        %stock{$_}++ for $a1, $a2;
        (my %to_transfer){$_} = my $number_of_pairs
            if $number_of_pairs = (%stock{$_} div 2) min %!p<stock>{$_}
            for $a1, $a2;
        $.transfer("stock", $!cp, %to_transfer)
            if %to_transfer;
        unless %!p.exists(++$!cp) {
            $!cp = "player_1";
        }
    }
}

use Test;

{
    my $game = Game.new(p => {}, fd => { <rabbit> }, wd => { <rabbit> });
    $game.play_round();
    is_deeply $game.e, [{
        type    => "transfer",
        from    => "stock",
        to      => "player_1",
        animals => { rabbit => 1 },
    }], "rolling two rabbits gives you a rabbit";
}

{
    my $game = Game.new(p => {}, fd => { <rabbit> }, wd => { <sheep> });
    $game.play_round();
    is_deeply $game.e, [], "rolling rabbit/sheep gives you nothing";
}

{
    my $game = Game.new(p => {player_1 => { rabbit => 2 }},
                        fd => { <rabbit> }, wd => { <sheep> });
    $game.play_round();
    is_deeply $game.e, [{
        type    => "transfer",
        from    => "stock",
        to      => "player_1",
        animals => { rabbit => 1 },
    }], "rolling rabbit/sheep if you already have 2 rabbits => 1 rabbit";
}

{
    my $game = Game.new(p => {player_1 => { rabbit => 3 }},
                        fd => { <rabbit> }, wd => { <sheep> });
    $game.play_round();
    is_deeply $game.e, [{
        type    => "transfer",
        from    => "stock",
        to      => "player_1",
        animals => { rabbit => 2 },
    }], "rolling rabbit/sheep if you already have 3 rabbits => 2 rabbits";
}

{
    my $game = Game.new(p => {player_1 => { rabbit => 15 }},
                        fd => { <fox> }, wd => { <rabbit> });
    $game.play_round();
    is_deeply $game.e, [{
        type    => "transfer",
        from    => "player_1",
        to      => "stock",
        animals => { rabbit => 15 },
    }], "fox with no small dog => lose all your rabbits";
}

{
    my $game = Game.new(p => {player_1 => { rabbit => 0 }},
                        fd => { <fox> }, wd => { <rabbit> });
    $game.play_round();
    is_deeply $game.e, [], "fox but no rabbits => nothing";
}

{
    my $game = Game.new(p => {player_1 => { rabbit => 15, small_dog => 1 }},
                        fd => { <fox> }, wd => { <sheep> });
    $game.play_round();
    is_deeply $game.e, [{
        type    => "transfer",
        from    => "player_1",
        to      => "stock",
        animals => { small_dog => 1 },
    }], "fox with a small dog => lose the small dog";
}

{
    my $game = Game.new(p => {player_1 => { rabbit => 1, sheep => 1,
                                            pig => 1, cow => 1 }},
                        fd => { <rabbit> }, wd => { <wolf> });
    $game.play_round();
    is_deeply $game.e, [{
        type    => "transfer",
        from    => "player_1",
        to      => "stock",
        animals => { rabbit => 1, sheep => 1, pig => 1, cow => 1 },
    }], "wolf eats rabbits, sheep, pigs, and cows";
}

{
    my $game = Game.new(p => {player_1 => { horse => 1, small_dog => 1 }},
                        fd => { <rabbit> }, wd => { <wolf> });
    $game.play_round();
    is_deeply $game.e, [], "wolf doesn't eat horses and small dogs";
}

{
    my $game = Game.new(p => {player_1 => { rabbit => 1, sheep => 1,
                                            pig => 1, cow => 1,
                                            big_dog => 1 }},
                        fd => { <horse> }, wd => { <wolf> });
    $game.play_round();
    is_deeply $game.e, [{
        type    => "transfer",
        from    => "player_1",
        to      => "stock",
        animals => { big_dog => 1 },
    }], "wolf with a big dog => lose the big dog";
}

{
    my $game = Game.new(p => {player_1 => { rabbit => 1, sheep => 1,
                                            pig => 1, cow => 1 }},
                        fd => { <fox> }, wd => { <wolf> });
    $game.play_round();
    is_deeply $game.e, [{
        type    => "transfer",
        from    => "player_1",
        to      => "stock",
        animals => { rabbit => 1, sheep => 1, pig => 1, cow => 1 },
    }], "both fox and wolf and no protection => same as wolf";
}

{
    my $game = Game.new(p => {stock => { rabbit => 10 },
                              player_1 => { rabbit => 25 }},
                        fd => { <rabbit> }, wd => { <rabbit> });
    $game.play_round();
    is_deeply $game.e, [{
        type    => "transfer",
        from    => "stock",
        to      => "player_1",
        animals => { rabbit => 10 },
    }], "you only get as many animals as there are in stock";
}

{
    my $game = Game.new(p => {player_1 => { rabbit => 5, small_dog => 1 }},
                        fd => { <fox> }, wd => { <rabbit> });
    $game.play_round();
    is_deeply $game.e, [{
        type    => "transfer",
        from    => "player_1",
        to      => "stock",
        animals => { small_dog => 1 },
    }, {
        type    => "transfer",
        from    => "stock",
        to      => "player_1",
        animals => { rabbit => 3 },
    }], "breeding can happen after the fox came";
}

{
    my $game = Game.new(p => {player_1 => { rabbit => 3 },
                              player_2 => { sheep => 5 }},
                        fd => { <rabbit> }, wd => { <sheep> });
    $game.play_round() for ^2;
    is_deeply $game.e, [{
        type    => "transfer",
        from    => "stock",
        to      => "player_1",
        animals => { rabbit => 2 },
    }, {
        type    => "transfer",
        from    => "stock",
        to      => "player_2",
        animals => { sheep => 3 },
    }], "two players playing one after the other";
}
