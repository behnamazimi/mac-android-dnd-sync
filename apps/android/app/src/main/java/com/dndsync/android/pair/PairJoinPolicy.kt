package com.dndsync.android.pair

object PairJoinPolicy {
    enum class Action {
        AlreadyJoined,
        JoinExistingIdentity,
        ReplaceAndJoin,
    }

    fun action(storedPairId: String?, storedJoined: Boolean, incomingPairId: String): Action {
        if (storedPairId == incomingPairId) {
            return if (storedJoined) Action.AlreadyJoined else Action.JoinExistingIdentity
        }
        return Action.ReplaceAndJoin
    }
}
