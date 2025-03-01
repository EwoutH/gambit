#
# This file is part of Gambit
# Copyright (c) 1994-2022, The Gambit Project (http://www.gambit-project.org)
#
# FILE: src/python/gambit/lib/outcome.pxi
# Cython wrapper for outcomes
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
cdef class Outcome:
    cdef c_GameOutcome outcome
    cdef StrategicRestriction restriction
    
    def __repr__(self):
        return (
            f"<Outcome [{self.outcome.deref().GetNumber()-1}] '{self.label}' "
            f"in game '{self.game.title}'>"
        )
    
    def __richcmp__(Outcome self, other, whichop):
        if isinstance(other, Outcome):
            if whichop == 2:
                return self.outcome.deref() == ((<Outcome>other).outcome).deref()
            elif whichop == 3:
                return self.outcome.deref() != ((<Outcome>other).outcome).deref()
            else:
                raise NotImplementedError
        else:
            if whichop == 2:
                return False
            elif whichop == 3:
                return True
            else:
                raise NotImplementedError

    def __hash__(self):
        return long(<long>self.outcome.deref())

    def delete(self):
        if self.restriction is not None:
            raise UndefinedOperationError("Changing objects in a restriction is not supported")
        (<Game>self.game).game.deref().DeleteOutcome(self.outcome)

    property game:
        def __get__(self):
            cdef Game g
            if self.restriction is not None:
                return self.restriction
            g = Game()
            g.game = self.outcome.deref().GetGame()
            return g

    property label:
        def __get__(self):
            return self.outcome.deref().GetLabel().decode('ascii')
        def __set__(self, value):
            if self.restriction is not None:
                raise UndefinedOperationError("Changing objects in a restriction is not supported")
            if value in [i.label for i in self.game.outcomes]:
                warnings.warn("Another outcome with an identical label exists")
            self.outcome.deref().SetLabel(value.encode('ascii'))

    def __getitem__(self, player):
        cdef bytes py_string
        if isinstance(player, Player):
            py_string = self.outcome.deref().GetPayoffNumber(player.number+1).as_string().c_str()
        elif isinstance(player, str):
            number = self.game.players[player].number
            py_string = self.outcome.deref().GetPayoffNumber(number+1).as_string().c_str()
        elif isinstance(player, int):
            py_string = self.outcome.deref().GetPayoffNumber(player+1).as_string().c_str()
        if "." in py_string.decode('ascii'):
            return decimal.Decimal(py_string.decode('ascii'))
        else:
            return Rational(py_string.decode('ascii'))

    def __setitem__(self, pl, value):
        if self.restriction is not None:
            raise UndefinedOperationError("Changing objects in a support is not supported")
        cdef string s
        if isinstance(value, int) or isinstance(value, decimal.Decimal) or \
           isinstance(value, fractions.Fraction):
            v = str(value)
            s = v.encode('ascii')
            self.outcome.deref().SetPayoff(pl+1, s)
        else:
            raise TypeError("payoff argument should be a numeric type instance")

    def unrestrict(self):
        cdef Outcome o
        o = Outcome()
        o.outcome = self.outcome
        return o

cdef class TreeGameOutcome:
    "Represents an outcome in a strategic game derived from an extensive game."
    cdef c_PureStrategyProfile *psp
    cdef c_Game c_game

    property game:
        def __get__(self):
            cdef Game g
            g = Game()
            g.game = self.c_game
            return g

    def __del__(self):
        del self.psp

    def __repr__(self):
        return f"<Outcome '{self.label}' in game '{self.game.title}'>"

    def __richcmp__(TreeGameOutcome self, other, whichop):
        if isinstance(other, TreeGameOutcome):
            if whichop == 2:
                return self.psp.deref() == ((<TreeGameOutcome>other).psp).deref()
            elif whichop == 3:
                return self.psp.deref() != ((<TreeGameOutcome>other).psp).deref()
            else:
                raise NotImplementedError
        else:
            if whichop == 2:
                return False
            elif whichop == 3:
                return True
            else:
                raise NotImplementedError

    def __getitem__(self, player):
        if isinstance(player, Player):
            return rat_to_py(self.psp.deref().GetPayoff(player.number+1))
        elif isinstance(player, str):
            number = self.game.players[player].number
            return rat_to_py(self.psp.deref().GetPayoff(number+1))
        elif isinstance(player, int):
            if player < 0 or player >= self.c_game.deref().NumPlayers():
                raise IndexError("Index out of range")
            return rat_to_py(self.psp.deref().GetPayoff(player+1))
        raise TypeError("player index should be a Player, int or str instance; {} passed"
                        .format(player.__class__.__name__))

    def __setitem__(self, pl, value):
        raise NotImplementedError("Cannot modify outcomes in a derived strategic game.")

    def delete(self):
        raise NotImplementedError("Cannot modify outcomes in a derived strategic game.")

    property label:
        def __get__(self):
            return "(%s)" % ( ",".join( [ self.psp.deref().GetStrategy((<Player>player).player).deref().GetLabel().c_str() for player in self.game.players ] ) )
        def __set__(self, char *value):
            raise NotImplementedError("Cannot modify outcomes in a derived strategic game.")
