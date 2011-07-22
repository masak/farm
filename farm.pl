class Game {
    has %!p;
    has &!fd;
    has &!wd;
    has @.e;
    has $!cp;
    has %!t;

    submethod BUILD(:%!p, :&!fd, :&!wd, :@!e, :$!cp = 'player_1', :%!t) {
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
        if (%!t{$!cp} // {;})() -> %trade {
            $.transfer($!cp, %trade<with>, %trade<selling>);
            $.transfer(%trade<with>, $!cp, %trade<buying>);
        }

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

## RAKUDO: If you're wondering about all the empty hashes that we're passing
##         into the constructor calls below, that's to work around a rakudobug
##         whose number I don't have right now because I'm offline, which I
##         will supply later. The bug causes a Null PMC access whenever we
##         don't pass in a hash, and the BUILD submethod expects a named hash
##         as a parameter.

{
    my $game = Game.new(p => {}, t => {},
                        fd => { <rabbit> }, wd => { <rabbit> });
    $game.play_round();
    is_deeply $game.e, [{
        type    => "transfer",
        from    => "stock",
        to      => "player_1",
        animals => { rabbit => 1 },
    }], "rolling two rabbits gives you a rabbit";
}

{
    my $game = Game.new(p => {}, t => {},
                        fd => { <rabbit> }, wd => { <sheep> });
    $game.play_round();
    is_deeply $game.e, [], "rolling rabbit/sheep gives you nothing";
}

{
    my $game = Game.new(p => {player_1 => { rabbit => 2 }}, t => {},
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
    my $game = Game.new(p => {player_1 => { rabbit => 3 }}, t => {},
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
    my $game = Game.new(p => {player_1 => { rabbit => 15 }}, t => {},
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
    my $game = Game.new(p => {player_1 => { rabbit => 0 }}, t => {},
                        fd => { <fox> }, wd => { <rabbit> });
    $game.play_round();
    is_deeply $game.e, [], "fox but no rabbits => nothing";
}

{
    my $game = Game.new(p => {player_1 => { rabbit => 15, small_dog => 1 }},
                        t => {}, fd => { <fox> }, wd => { <sheep> });
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
                        t => {}, fd => { <rabbit> }, wd => { <wolf> });
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
                        t => {}, fd => { <rabbit> }, wd => { <wolf> });
    $game.play_round();
    is_deeply $game.e, [], "wolf doesn't eat horses and small dogs";
}

{
    my $game = Game.new(p => {player_1 => { rabbit => 1, sheep => 1,
                                            pig => 1, cow => 1,
                                            big_dog => 1 }},
                        t => {}, fd => { <horse> }, wd => { <wolf> });
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
                        t => {}, fd => { <fox> }, wd => { <wolf> });
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
                        t => {}, fd => { <rabbit> }, wd => { <rabbit> });
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
                        t => {}, fd => { <fox> }, wd => { <rabbit> });
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
                        t => {}, fd => { <rabbit> }, wd => { <sheep> });
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

{
    my $game = Game.new(p => {player_1 => { rabbit => 6 },
                              player_2 => { sheep => 1 }},
                        t => {player_1 => sub { return {
                                type => "trade",
                                with => "player_2",
                                selling => { rabbit => 6 },
                                buying  => { sheep => 1 },
                             }}},
                        fd => { <horse> }, wd => { <cow> });
    $game.play_round();
    is_deeply $game.e, [{
        type    => "transfer",
        from    => "player_1",
        to      => "player_2",
        animals => { rabbit => 6 },
    }, {
        type    => "transfer",
        from    => "player_2",
        to      => "player_1",
        animals => { sheep => 1 },
    }], "p1 makes a successful trade with p2: 6 rabbits for 1 sheep";
}

{
    my $game = Game.new(p => {player_1 => { rabbit => 5 },
                              player_2 => { sheep => 1 }},
                        t => {player_1 => sub { return {
                                type => "trade",
                                with => "player_2",
                                selling => { rabbit => 6 },
                                buying  => { sheep => 1 },
                             }}},
                        fd => { <horse> }, wd => { <cow> });
    $game.play_round();
    is_deeply $game.e, [], "p1 doesn't have enough animals: no trade";
}
