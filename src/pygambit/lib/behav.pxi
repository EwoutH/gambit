#
# This file is part of Gambit
# Copyright (c) 1994-2022, The Gambit Project (http://www.gambit-project.org)
#
# FILE: src/python/gambit/lib/behav.pxi
# Cython wrapper for behavior strategies
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
import functools

from libcpp cimport bool
from cython.operator cimport dereference as deref

cdef class MixedBehaviorProfile(object):
    def __repr__(self):    
        return str([ self[player] for player in self.game.players ])
    def _repr_latex_(self):
        return r"$\left[" + ",".join([ self[player]._repr_latex_().replace("$","") for player in self.game.players ]) + r"\right]$"

    def __richcmp__(MixedBehaviorProfile self, other, whichop):
        if whichop == 0:
            return list(self) < list(other)
        elif whichop == 1:
            return list(self) <= list(other)
        elif whichop == 2:
            return list(self) == list(other)
        elif whichop == 3:
            return list(self) != list(other)
        elif whichop == 4:
            return list(self) > list(other)
        else:
            return list(self) >= list(other)

    def _resolve_index(self, index, players=True):
        # Given a string index, resolve into a player or action object.
        if players:
            try:
                # first check to see if string is referring to a player
                return self.game.players[index]
            except IndexError:
                pass

        # if no player matches, check infoset labels
        infosets = functools.reduce(lambda x,y: x+y,
                                    [list(p.infosets) 
                                     for p in self.game.players]) 
        matches = list(filter(lambda x: x.label==index, infosets))
        if len(matches) == 1:
            return matches[0]
        elif len(matches) > 1:
            raise IndexError("multiple infosets matching label '%s'" % index)
        
        # if no infoset matches, check action labels
        actions = functools.reduce(lambda x,y: x+y,
                                   [list(i.actions) 
                                    for p in self.game.players
                                    for i in p.infosets])
        matches = list(filter(lambda x: x.label==index, actions))
        if len(matches) == 1:
            return matches[0]
        elif len(matches) == 0:
            if players:
                raise IndexError("no player, infoset or action matching label '%s'" % index)
            else:
                raise IndexError("no infoset or action matching label '%s'" % index)
        else:
            raise IndexError("multiple actions matching label '%s'" % index)

    def _setinfoset(self, index, value):
        if len(index.actions) == len(value):
            for action, val in zip(index.actions, value):
                self._setaction(action, val)
        else:
            raise ValueError("value list length must be %s, not %s" %
                             (len(index.actions), len(value)))

    def _setplayer(self, index, value):
        if len(index.infosets) == len(value):
            for infoset, val in zip(index.infosets, value):
                self._setinfoset(infoset, val)
        else:
            raise ValueError("value list length must be %s, not %s" %
                             (len(index.actions), len(value)))

    def __getitem__(self, index):
        if isinstance(index, int):
            return self._getprob(index+1)
        elif isinstance(index, Action):
            return self._getaction(index)
        elif isinstance(index, Infoset):
            class MixedBehavInfoset(object):
                def __init__(self, profile, infoset):
                    self.profile = profile
                    self.infoset = infoset
                def __eq__(self, other):
                    return list(self) == list(other)
                def __len__(self):
                    return len(self.infoset.actions)
                def __repr__(self):
                    return str(list(self.profile[self.infoset]))
                def _repr_latex_(self):
                    if isinstance(self.profile, MixedBehaviorProfileRational):
                       return r"$\left[" + ",".join(self.profile[i]._repr_latex_().replace("$","") for i in self.infoset.actions) + r"\right]$"
                    else:
                       return repr(self)
                def __getitem__(self, index):
                    return self.profile[self.infoset.actions[index]]
                def __setitem__(self, index, value):
                    self.profile[self.infoset.actions[index]] = value
            return MixedBehavInfoset(self, index)
        elif isinstance(index, Player):
            class MixedBehav(object):
                def __init__(self, profile, player):
                    self.profile = profile
                    self.player = player
                def __eq__(self, other):
                    return list(self) == list(other)
                def __len__(self):
                    return len(self.player.infosets)
                def __repr__(self):
                    return str(list(self.profile[self.player]))
                def _repr_latex_(self):
                    if isinstance(self.profile, MixedBehaviorProfileRational):
                       return r"$\left[" + ",".join(self.profile[i]._repr_latex_().replace("$","") for i in self.player.infosets) + r"\right]$"
                    else:
                       return repr(self)
                def __getitem__(self, index):
                    return self.profile[self.player.infosets[index]]
                def __setitem__(self, index, value):
                    self.profile[self.player.infosets[index]] = value
            return MixedBehav(self, index)
        elif isinstance(index, str):
            return self[self._resolve_index(index, players=True)]
        else:
            raise TypeError("profile indexes must be int, str, Player, Infoset or Action, not %s" %
                            index.__class__.__name__)

    def __setitem__(self, index, value):
        if isinstance(index, int):
            self._setprob(index+1, value)
        elif isinstance(index, Action):
            self._setaction(index, value)
        elif isinstance(index, Infoset):
            self._setinfoset(index,value)
        elif isinstance(index, Player):
            self._setplayer(index, value)
        elif isinstance(index, str):
            self[self._resolve_index(index)] = value
        else:
            raise TypeError("profile indexes must be int, str, Player, Infoset or Action, not %s" %
                            index.__class__.__name__)

    def is_defined_at(self, infoset):
        if isinstance(infoset, str):
            infoset = self._resolve_index(infoset, players=False)
            if not isinstance(infoset, Infoset):
                raise IndexError("no infoset matching label '%s'" % infoset.label)
        elif not isinstance(infoset, Infoset):
            raise TypeError("profile infoset index must be str or Infoset, not %s" %
                            infoset.__class__.__name__)
        return self._is_defined_at(infoset)

    def belief(self, node):
        if isinstance(node, Node):
            return self._belief(node)
        elif isinstance(node, Infoset):
            return [self._belief(n) for n in node.members]
        raise TypeError("profile belief index must be Node or Infoset, not %s" %
                        node.__class__.__name__)    

    def action_prob(self, action):
        if isinstance(action, str):
            action = self._resolve_index(action, players=False)
            if not isinstance(action, Action):
                raise IndexError("no action matching label '%s'" % action.label)
        elif not isinstance(action, Action):
            raise TypeError("profile action probability index must be str or Action, not %s" %
                            action.__class__.__name__)
        return self._action_prob(action)

    def payoff(self, player_infoset_or_action):
        if isinstance(player_infoset_or_action, Player):
            return self._payoff(player_infoset_or_action)
        elif isinstance(player_infoset_or_action, Infoset):
            return self._infoset_payoff(player_infoset_or_action)
        elif isinstance(player_infoset_or_action, Action):
            return self._action_payoff(player_infoset_or_action)
        elif isinstance(player_infoset_or_action, str):
            try:
                return self.payoff(self.game.players[player_infoset_or_action])
            except IndexError:
                infoset_or_action = self._resolve_index(player_infoset_or_action, players=False)
                if isinstance(infoset_or_action, Infoset):
                    return self._infoset_payoff(infoset_or_action)
                elif isinstance(infoset_or_action, Action):
                    return self._action_payoff(infoset_or_action)
                raise IndexError("no matching label '%s'" % infoset_or_action.label)
        raise TypeError("profile payoffs index must be int, str, Player, Infoset or Action, not %s" %
                        player_infoset_or_action.__class__.__name__)

    def realiz_prob(self, infoset_or_action):
        if isinstance(infoset_or_action, Infoset):
            return self._infoset_prob(infoset_or_action)
        elif isinstance(infoset_or_action, Action):
            return self._action_prob(infoset_or_action)
        elif isinstance(infoset_or_action, str):
            infoset_or_action = infoset = self._resolve_index(infoset_or_action, players=False)
            if isinstance(infoset_or_action, Infoset):
                return self._infoset_prob(infoset_or_action)
            elif isinstance(infoset_or_action, Action):
                return self._action_prob(infoset_or_action)
        raise TypeError("profile probability index must be str, Infoset or Action, not %s" %
                        infoset_or_action.__class__.__name__)

    def regret(self, action):
        if isinstance(action, str):
            action = self._resolve_index(action, players=False)
            if not isinstance(action, Action):
                raise IndexError("no action matching label '%s'" % action.label)
        elif not isinstance(action, Action):
            raise TypeError("profile regret index must be str or Action, not %s" %
                            action.__class__.__name__)
        return self._regret(action)    

cdef class MixedBehaviorProfileDouble(MixedBehaviorProfile):
    cdef c_MixedBehaviorProfileDouble *profile

    def __dealloc__(self):
        del self.profile
    def __len__(self):
        return self.profile.Length()

    def _is_defined_at(self, Infoset infoset):
        return self.profile.IsDefinedAt(infoset.infoset)
    def _getprob(self, int index):
        return self.profile.getitem(index)
    def _getaction(self, Action index):
        return self.profile.getaction(index.action)
    def _setprob(self, int index, value):
        setitem_mbpd_int(self.profile, index, value)
    def _setaction(self, Action index, value):
        setitem_mbpd_action(self.profile, index.action, value)
    def _payoff(self, Player player):
        return self.profile.GetPayoff(player.player.deref().GetNumber())
    def _belief(self, Node node):
        return self.profile.GetBeliefProb(node.node)
    def _infoset_prob(self, Infoset infoset):
        return self.profile.GetRealizProb(infoset.infoset)
    def _infoset_payoff(self, Infoset infoset):
        return self.profile.GetPayoff(infoset.infoset)
    def _action_prob(self, Action action):
        return self.profile.GetActionProb(action.action)
    def _action_payoff(self, Action action):
        return self.profile.GetPayoff(action.action)
    def _regret(self, Action action):
        return self.profile.GetRegret(action.action)

    def copy(self):
        cdef MixedBehaviorProfileDouble behav
        behav = MixedBehaviorProfileDouble()
        behav.profile = new c_MixedBehaviorProfileDouble(deref(self.profile))
        return behav
    def as_strategy(self):
        cdef MixedStrategyProfileDouble mixed
        mixed = MixedStrategyProfileDouble()
        mixed.profile = new c_MixedStrategyProfileDouble(deref(self.profile).ToMixedProfile())
        return mixed
    def liap_value(self):
        return self.profile.GetLiapValue()
    def set_centroid(self):   self.profile.SetCentroid()
    def normalize(self):      self.profile.Normalize()
    def randomize(self, denom=None):
        if denom is None:
            self.profile.Randomize()
        else:
            self.profile.Randomize(denom)

    property game:
        def __get__(self):
            cdef Game g
            g = Game()
            g.game = self.profile.GetGame()
            return g


cdef class MixedBehaviorProfileRational(MixedBehaviorProfile):
    cdef c_MixedBehaviorProfileRational *profile

    def __dealloc__(self):
        del self.profile
    def __len__(self):
        return self.profile.Length()

    def _is_defined_at(self, Infoset infoset):
        return self.profile.IsDefinedAt(infoset.infoset)
    def _getprob(self, int index):
        return rat_to_py(self.profile.getitem(index))
    def _getaction(self, Action index):
        return rat_to_py(self.profile.getaction(index.action))
    def _setprob(self, int index, value):
        if not isinstance(value, (int, fractions.Fraction)):
            raise TypeError("rational precision profile requires int or Fraction probability, not %s" %
                            value.__class__.__name__)
        setitem_mbpr_int(self.profile, index, to_rational(str(value).encode('ascii')))
    def _setaction(self, Action index, value):
        if not isinstance(value, (int, fractions.Fraction)):
            raise TypeError("rational precision profile requires int or Fraction probability, not %s" %
                            value.__class__.__name__)
        setitem_mbpr_action(self.profile, index.action,
                            to_rational(str(value).encode('ascii')))
    def _payoff(self, Player player):
        return rat_to_py(self.profile.GetPayoff(player.player.deref().GetNumber()))
    def _belief(self, Node node):
        return rat_to_py(self.profile.GetBeliefProb(node.node))
    def _infoset_prob(self, Infoset infoset):
        return rat_to_py(self.profile.GetRealizProb(infoset.infoset))
    def _infoset_payoff(self, Infoset infoset):
        return rat_to_py(self.profile.GetPayoff(infoset.infoset))
    def _action_prob(self, Action action):
        return rat_to_py(self.profile.GetActionProb(action.action))
    def _action_payoff(self, Action action):
        return rat_to_py(self.profile.GetPayoff(action.action))
    def _regret(self, Action action):
        return rat_to_py(self.profile.GetRegret(action.action))
    
    def copy(self):
        cdef MixedBehaviorProfileRational behav
        behav = MixedBehaviorProfileRational()
        behav.profile = new c_MixedBehaviorProfileRational(deref(self.profile))
        return behav
    def as_strategy(self):
        cdef MixedStrategyProfileRational mixed
        mixed = MixedStrategyProfileRational()
        mixed.profile = new c_MixedStrategyProfileRational(deref(self.profile).ToMixedProfile())
        return mixed
    def liap_value(self):
        return rat_to_py(self.profile.GetLiapValue())
    def set_centroid(self):   self.profile.SetCentroid()
    def normalize(self):      self.profile.Normalize()
    def randomize(self, denom):
        self.profile.Randomize(denom)

    property game:
        def __get__(self):
            cdef Game g
            g = Game()
            g.game = self.profile.GetGame()
            return g
