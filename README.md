See
[the lightning talk](http://masak.org/carl/yapc-eu-2011-little-animal-farm/talk.pdf)
for the AI challenge.

Players take turns. A turn consists of an optional exchange, followed by rolling dice.
The first player to get (at least) a rabbit, a sheep, a pig, a cow, and a horse, wins.

The player rolls the two (dodecahedral) dice, which look like this:

    Fox die: 6 rabbits, 2 sheep, 2 pigs, 1 horse, 1 fox
    Wolf die: 6 rabbits, 3 sheep, 1 pig, 1 cow, 1 wolf

Depending on the outcome of the roll, the animals may "breed" and the player may
end up with more animals as a result. The process behind this is best explained
by example:

* Player has no animals, but rolls two rabbits => 1 pair of rabbits.
  That gives the player 1 rabbit.

* Player already has three rabbits, but rolls at least one rabbit => 2 pairs.
  That gives the player 2 rabbits.

* Player has three rabbits and five sheep, and rolls a rabbit and a sheep => 2 pairs
  of rabbits and 3 pairs of sheep. Player gets 2 rabbits and 3 sheep.

* Player has 10 cows, and rolls a rabbit and a sheep => no new animals.
  Only the animals on the dice get to breed.

So, the animals breeding is determined by the dice, and the total number of animal
pairs (and thus the total number of new animals) is counted from the total number of
pairs in the player's inventory combined with the animals on the dice.

All the animals are taken from a place called the stock, which works like the bank in
many other games. If the stock cannot deliver a certain amount of animals, it just
delivers the maximal amount instead.

At the start of the game, the stock contains

    60 rabbits
    24 sheep
    20 pigs
    12 cows
     6 horses
     4 small dogs
     2 big dogs

A roll turning up a fox will result in all the player's rabbits being "eaten" and
returned to the stock, *unless* the player has (at least) one small dog, in which
case the small dog will be returned to the stock.

A roll turning up a wolf will result in all the player's rabbits, sheep, pigs and
cows being eaten and returned to the stock, *unless* the player has (at least) one
big dog, in which case the big dog will be returned to the stock. Wolves don't eat
small dogs or horses.

Before each roll, a player may make exactly one trade, either with the stock or
with another player. The other player may accept or deny; the stock always accepts.
There is no haggling, and the conversion rates between animals is fixed:

    6 rabbits <=> 1 sheep
    2 sheep   <=> 1 pig
    3 pigs    <=> 1 cow
    2 cows    <=> 1 horse
    1 sheep   <=> 1 small dog
    1 cow     <=> 1 big dog

An exchange may be struck as long as the total worth of the animals exchanged is
the same. For example, 2 pigs, 1 sheep, and 6 rabbits may be exchanged for 1 cow
(and vice versa). The following deals are allowed: one animal for one animal
(for example 1 sheep against 1 small dog), one animal for many animals (for
example 1 cow against 3 pigs), many animals for one (2 sheep against 1 pig).
However, many animals for many (for example 2 sheep and 5 pigs against 2 cows)
isn't allowed even when (as in this case) the total worth of the animals
exchanged is equal.

If the exchange is with the stock, and the stock has fewer animals of some kind
(for example 3 cows) than the amount desired (for example 4 cows), the lower amount
is traded. This is the only case where the total worth of the animals is allowed
not to add up.
