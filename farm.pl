class Game {
    has %!p;        # players (and stock): hash of hashes of animals
    has &!fd;       # fox  die code object
    has &!wd;       # wolf die code object
    has @.e;        # event queue: array of hashes representing events
    has $!cp;       # current player
    has %!t;        # player trading code objects
    has %!at;       # player accept trade code objects

    my @animals = <rabbit sheep pig cow horse small_dog big_dog>;

    submethod BUILD(:%!p, :&!fd, :&!wd, :@!e, :$!cp = 'player_1', :%!t, :%!at) {
        %!p<stock> //= hash @animals Z=> (60, 24, 20, 12, 6, 4, 2);
        &!fd //= { ('rabbit' xx 6, <sheep pig> xx 2, 'horse', 'fox').roll };
        &!wd //= { ('rabbit' xx 6, 'sheep' xx 3, 'pig', 'cow', 'wolf').roll };
    }

    sub enough_animals(%player, %to_trade) {
        !grep { %to_trade{$_} > (%player{$_} // 0) }, %to_trade.keys;
    }

    sub trunc_animals(%player, %to_trade) {
        hash map {; $_ => %to_trade{$_} min %player{$_} }, %to_trade.keys;
    }

    sub worth(%to_trade) {
        my %value = @animals Z=> (1, 6, 12, 36, 72, 6, 36);
        return [+] map -> $k, $v { $v * %value{$k} }, %to_trade.kv;
    }

    method publish(%event) { push @.e, {%event} }

    method transfer($from, $to, %animals) {
        for %animals.kv -> $animal, $amount {
            %!p{$from}{$animal} -= $amount; %!p{$from}{$animal}.=Int;
            %!p{$to  }{$animal} += $amount; %!p{$to  }{$animal}.=Int;
        }
        self.publish: { :type<transfer>, :$from, :$to, :%animals };
    }

    method play_round() {
        if (%!t{$!cp} // {;})(%!p) -> $_ {
            if !.exists("type") || .<type> ne "trade" {
                self.publish: { :type<failed>, :reason("Wrong type") };
            }
            elsif !enough_animals(%!p{$!cp}, .<selling>) {
                self.publish: { :type<failed>, :reason("Not enough animals" ) };
            }
            elsif !.exists("with") || !(my $op = %!p{.<with>}) {
                self.publish: { :type<failed>, :reason("Player doesn't exist") };
            }
            elsif .<with> ne 'stock' && !enough_animals($op, .<buying>) {
                self.publish: { :type<failed>, :reason("Not enough animals" ) };
            }
            elsif worth(.<selling>) != worth(.<buying>) {
                self.publish: { :type<failed>, :reason("Unequal trade") };
            }
            elsif not .{'selling'|'buying'}.values.reduce(&infix:<+>) == 1 {
                self.publish: { :type<failed>, :reason("Many-to-many trade" ) };
            }
            elsif (%!at{.<with>} // -> %, $ {True})(%!p, $!cp) {
                $.transfer($!cp, .<with>, .<selling>);
                $.transfer(.<with>, $!cp, trunc_animals($op, .<buying>));
            }
        }
        if self.someone_won {
            self.publish: { :type<win>, :who($!cp) };
            return;
        }

        my ($fd, $wd) = &!fd(), &!wd();
        self.publish: { :type<roll>, :player($!cp), :$fd, :$wd };
        sub prowl($predator, $guard, @victims) {
            if %!p{$!cp}{$guard} {
                $.transfer($!cp, "stock", { $guard => 1 });
            }
            else {
                (my %to_transfer){$_} = %!p{$!cp}{$_}
                    if %!p{$!cp}{$_}
                        for @victims;
                $.transfer($!cp, "stock", %to_transfer)
                    if %to_transfer;
            }
        }
        if $wd eq 'wolf' {
            prowl 'wolf', 'big_dog', <rabbit sheep pig cow>;
        }
        if $fd eq 'fox' {
            prowl 'fox', 'small_dog', <rabbit>.list;
        }

        my %stock = %!p{$!cp} // {};
        %stock{$_}++ for $fd, $wd;
        (my %to_transfer){$_} = my $number_of_pairs
            if $number_of_pairs = (%stock{$_} div 2) min %!p<stock>{$_}
                for $fd, $wd;
        $.transfer("stock", $!cp, %to_transfer)
            if %to_transfer;
        if self.someone_won {
            self.publish: { :type<win>, :who($!cp) };
            return;
        }
        unless %!p.exists(++$!cp) {
            $!cp = "player_1";
        }
    }

    method someone_won { so %!p{$!cp}{all <rabbit sheep pig cow horse>} }
    method who_won { self.someone_won ?? $!cp !! Nil }
}

multi MAIN() {
    my token word { <.alpha>+ }
    my regex offer {:s [ (\d+) (<&word> ** <.ws>) ] ** ',' }
    sub an(Match $m) { hash map {; ~$m[1][$_] => ~$m[0][$_] }, $m[0].keys }

    my $N = +((prompt "How many players? ") // exit);
    sub mt($p) {
        sub (%) { # Code lovingly st^Wcopied from sorear++'s version
            loop {
                given trim ((prompt "Player $p, make what trade? ") // exit) {
                    when /:s^ none $/ { return Nil; }
                    when /:s^ $0=<&offer> for $1=<&offer> with (.*) $/ {
                        return { :type<trade>, :with(~$2),
                                 :selling(an($0)), :buying(an($1)) };
                    }
                    default {
                        say "Illegal trade syntax.
Valid are 'none', '2 pig, 1 sheep, 6 rabbit for 1 cow with stock'.";
                        redo;
                    }
                }
            }
        }
    }
    sub mat($p) {
        sub (%, $op) {
            my $answer
                = ((prompt "Player $p, accept trade with $op? ") // exit);
            return so $answer.lc ~~ /^y[es]?$/;
        }
    }
    my $game = Game.new(
        p  => hash(map {; "player_$_" => {}      }, 1..$N),
        t  => hash(map {; "player_$_" => mt($_)  }, 1..$N),
        at => hash(map {; "player_$_" => mat($_) }, 1..$N),
    );
    my %p = stock => hash(<rabbit 60 sheep 24 pig 20 cow 12 horse 6
                           small_dog 4 big_dog 2>),
            hash(map {; "player_$_" => {} }, 1..$N);
    loop {
        my $ei = $game.e.elems;
        $game.play_round();
        for $game.e[$ei ..^ $game.e.elems] {
            when :type<roll> {
                say sprintf "%s rolls a %s and a %s", .<player>, .<fd>, .<wd>;
            }
            when :type<transfer> {
                sub s($n) { $n == 1 ?? "" !! "s" }
                say sprintf "%s gives %s %s", .<from>, .<to>,
                    join " and ", map { "$^v $^k" ~ s $v }, .<animals>.kv;
                for .<animals>.kv -> $animal, $amount {
                    %p{.<from>}{$animal} -= $amount;
                    %p{.<to>  }{$animal} += $amount;
                    %p{.<from>}.delete($animal) unless %p{.<from>}{$animal};
                }
            }
            when :type<failed> {
                say "Trade failed. Reason: $_.<reason>.";
            }
            when :type<win> {
                last;
            }
        }
        say;
        say "Current inventories:";
        for %p.pairs.sort {
            say .key, ": ", .value.invert.fmt("%s %s", ", ");
        }
    }
    say "$game.who_won() won!";
}

multi MAIN("test") {
    use Test;

    ## RAKUDO: If you're wondering about all the empty hashes that we're
    ##         passing into the constructor calls below, that's to work
    ##         around https://rt.perl.org/rt3/Ticket/Display.html?id=95340
    ##         The bug causes a Null PMC access whenever we don't pass in
    ##         a hash, and the BUILD submethod expects a named hash as
    ##         a parameter.

    sub non_rolls(@e) { [grep { .<type> ne 'roll' }, @e] }

    {
        my $game = Game.new(p => {}, t => {}, at => {},
                            fd => { <rabbit> }, wd => { <rabbit> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type    => "transfer",
            from    => "stock",
            to      => "player_1",
            animals => { rabbit => 1 },
        }], "rolling two rabbits gives you a rabbit";
    }

    {
        my $game = Game.new(p => {}, t => {}, at => {},
                            fd => { <rabbit> }, wd => { <sheep> });
        $game.play_round();
        is_deeply non_rolls($game.e), [],
            "rolling rabbit/sheep gives you nothing";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 2 }},
                            t => {}, at => {},
                            fd => { <rabbit> }, wd => { <sheep> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type    => "transfer",
            from    => "stock",
            to      => "player_1",
            animals => { rabbit => 1 },
        }], "rolling rabbit/sheep if you already have 2 rabbits => 1 rabbit";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 3 }},
                            t => {}, at => {},
                            fd => { <rabbit> }, wd => { <sheep> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type    => "transfer",
            from    => "stock",
            to      => "player_1",
            animals => { rabbit => 2 },
        }], "rolling rabbit/sheep if you already have 3 rabbits => 2 rabbits";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 15 }},
                            t => {}, at => {},
                            fd => { <fox> }, wd => { <rabbit> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type    => "transfer",
            from    => "player_1",
            to      => "stock",
            animals => { rabbit => 15 },
        }], "fox with no small dog => lose all your rabbits";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 0 }},
                            t => {}, at => {},
                            fd => { <fox> }, wd => { <rabbit> });
        $game.play_round();
        is_deeply non_rolls($game.e), [], "fox but no rabbits => nothing";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 15, small_dog => 1 }},
                            t => {}, at => {},
                            fd => { <fox> }, wd => { <sheep> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type    => "transfer",
            from    => "player_1",
            to      => "stock",
            animals => { small_dog => 1 },
        }], "fox with a small dog => lose the small dog";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 1, sheep => 1,
                                                pig => 1, cow => 1 }},
                            t => {}, at => {},
                            fd => { <rabbit> }, wd => { <wolf> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type    => "transfer",
            from    => "player_1",
            to      => "stock",
            animals => { rabbit => 1, sheep => 1, pig => 1, cow => 1 },
        }], "wolf eats rabbits, sheep, pigs, and cows";
    }

    {
        my $game = Game.new(p => {player_1 => { horse => 1, small_dog => 1 }},
                            t => {}, at => {},
                            fd => { <rabbit> }, wd => { <wolf> });
        $game.play_round();
        is_deeply non_rolls($game.e), [],
            "wolf doesn't eat horses and small dogs";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 1, sheep => 1,
                                                pig => 1, cow => 1,
                                                big_dog => 1 }},
                            t => {}, at => {},
                            fd => { <horse> }, wd => { <wolf> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type    => "transfer",
            from    => "player_1",
            to      => "stock",
            animals => { big_dog => 1 },
        }], "wolf with a big dog => lose the big dog";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 1, sheep => 1,
                                                pig => 1, cow => 1 }},
                            t => {}, at => {},
                            fd => { <fox> }, wd => { <wolf> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type    => "transfer",
            from    => "player_1",
            to      => "stock",
            animals => { rabbit => 1, sheep => 1, pig => 1, cow => 1 },
        }], "both fox and wolf and no protection => same as wolf";
    }

    {
        my $game = Game.new(p => {stock => { rabbit => 10 },
                                  player_1 => { rabbit => 25 }},
                            t => {}, at => {},
                            fd => { <rabbit> }, wd => { <rabbit> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type    => "transfer",
            from    => "stock",
            to      => "player_1",
            animals => { rabbit => 10 },
        }], "you only get as many animals as there are in stock";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 5, small_dog => 1 }},
                            t => {}, at => {},
                            fd => { <fox> }, wd => { <rabbit> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
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
                            t => {}, at => {},
                            fd => { <rabbit> }, wd => { <sheep> });
        $game.play_round() for ^2;
        is_deeply non_rolls($game.e), [{
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
                            t => {player_1 => sub (%) { return {
                                    type => "trade",
                                    with => "player_2",
                                    selling => { rabbit => 6 },
                                    buying  => { sheep => 1 },
                                 }}},
                            at => {},
                            fd => { <horse> }, wd => { <cow> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
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
                            t => {player_1 => sub (%) { return {
                                    type => "trade",
                                    with => "player_2",
                                    selling => { rabbit => 6 },
                                    buying  => { sheep => 1 },
                                 }}},
                            at => {},
                            fd => { <horse> }, wd => { <cow> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type     => "failed",
            "reason" => "Not enough animals"
        }], "p1 doesn't have enough animals: no trade";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 6 },
                                  player_2 => { cow => 3 }},
                            t => {player_1 => sub (%) { return {
                                    type => "trade",
                                    with => "player_2",
                                    selling => { rabbit => 6 },
                                    buying  => { sheep => 1 },
                                 }}},
                            at => {},
                            fd => { <horse> }, wd => { <sheep> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type     => "failed",
            "reason" => "Not enough animals"
        }], "p2 doesn't have enough animals: no trade";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 6 },
                                  player_2 => { sheep => 1 }},
                            t => {player_1 => sub (%) { return {
                                    with => "player_2",
                                    selling => { rabbit => 6 },
                                    buying  => { sheep => 1 },
                                 }}},
                            at => {},
                            fd => { <horse> }, wd => { <sheep> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type     => "failed",
            "reason" => "Wrong type"
        }], ":type key missing: no trade";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 6 },
                                  player_2 => { sheep => 1 }},
                            t => {player_1 => sub (%) { return {
                                    type => "scintillating muffin party",
                                    with => "player_2",
                                    selling => { rabbit => 6 },
                                    buying  => { sheep => 1 },
                                 }}},
                            at => {},
                            fd => { <horse> }, wd => { <sheep> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type     => "failed",
            "reason" => "Wrong type"
        }], ":type key not 'trade': no trade";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 6 },
                                  player_2 => { sheep => 1 }},
                            t => {player_1 => sub (%) { return {
                                    type => "trade",
                                    selling => { rabbit => 6 },
                                    buying  => { sheep => 1 },
                                 }}},
                            at => {},
                            fd => { <horse> }, wd => { <sheep> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type     => "failed",
            "reason" => "Player doesn't exist"
        }], ":with key missing: no trade";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 6 },
                                  player_2 => { sheep => 1 }},
                            t => {player_1 => sub (%) { return {
                                    type => "trade",
                                    with => "player_8",
                                    selling => { rabbit => 6 },
                                    buying  => { sheep => 1 },
                                 }}},
                            at => {},
                            fd => { <horse> }, wd => { <sheep> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type     => "failed",
            "reason" => "Player doesn't exist"
        }], ":with key contains illegal player: no trade";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 6 }},
                            t => {player_1 => sub (%) { return {
                                    type => "trade",
                                    with => "stock",
                                    selling => { rabbit => 6 },
                                    buying  => { sheep => 1 },
                                 }}},
                            at => {},
                            fd => { <horse> }, wd => { <cow> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type    => "transfer",
            from    => "player_1",
            to      => "stock",
            animals => { rabbit => 6 },
        }, {
            type    => "transfer",
            from    => "stock",
            to      => "player_1",
            animals => { sheep => 1 },
        }], "successful trade with the stock";
    }

    {
        my $game = Game.new(p => {stock => { sheep => 1 },
                                  player_1 => { pig => 1 }},
                            t => {player_1 => sub (%) { return {
                                    type => "trade",
                                    with => "stock",
                                    selling => { pig => 1 },
                                    buying  => { sheep => 2 },
                                 }}},
                            at => {},
                            fd => { <horse> }, wd => { <cow> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type    => "transfer",
            from    => "player_1",
            to      => "stock",
            animals => { pig => 1 },
        }, {
            type    => "transfer",
            from    => "stock",
            to      => "player_1",
            animals => { sheep => 1 },
        }], "when stock doesn't have enough, it gives all it has";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 6 },
                                  player_2 => { sheep => 1 }},
                            t => {player_1 => sub (%) { return {
                                    type => "trade",
                                    with => "player_2",
                                    selling => { rabbit => 4 },
                                    buying  => { sheep => 1 },
                                 }}},
                            at => {},
                            fd => { <horse> }, wd => { <cow> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type     => "failed",
            "reason" => "Unequal trade"
        }],
            "total values of animal pools don't match up: no trade";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 12 },
                                  player_2 => { sheep => 2 }},
                            t => {player_1 => sub (%) { return {
                                    type => "trade",
                                    with => "player_2",
                                    selling => { rabbit => 12 },
                                    buying  => { sheep => 2 },
                                 }}},
                            at => {},
                            fd => { <horse> }, wd => { <cow> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type     => "failed",
            "reason" => "Many-to-many trade"
        }], "many animals against many animals: no trade";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 6 },
                                  player_2 => { sheep => 1 }},
                            t => {player_1 => sub (%) { return {
                                    type => "trade",
                                    with => "player_2",
                                    selling => { rabbit => 6 },
                                    buying  => { sheep => 1 },
                                 }}},
                            at => {player_2 => sub (%, $) { False }},
                            fd => { <horse> }, wd => { <cow> });
        $game.play_round();
        is_deeply non_rolls($game.e), [], "p2 declines: no trade";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 1, sheep => 1,
                                                pig => 1, cow => 3 }},
                            t => {player_1 => sub (%) { return {
                                    type => "trade",
                                    with => "stock",
                                    selling => { cow => 2 },
                                    buying  => { horse => 1 },
                                 }}},
                            at => {},
                            fd => { <fox> }, wd => { <wolf> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type    => "transfer",
            from    => "player_1",
            to      => "stock",
            animals => { cow => 2 },
        }, {
            type    => "transfer",
            from    => "stock",
            to      => "player_1",
            animals => { horse => 1 },
        }, {
            type    => "win",
            who     => "player_1",
        }], "winning by trading with stock";
    }

    {
        my $game = Game.new(p => {player_1 => { rabbit => 1, pig => 1,
                                                cow => 1, horse => 1 }},
                            t => {}, at => {},
                            fd => { <sheep> }, wd => { <sheep> });
        $game.play_round();
        is_deeply non_rolls($game.e), [{
            type    => "transfer",
            from    => "stock",
            to      => "player_1",
            animals => { sheep => 1 },
        }, {
            type    => "win",
            who     => "player_1",
        }], "winning by throwing dice";
    }
}
