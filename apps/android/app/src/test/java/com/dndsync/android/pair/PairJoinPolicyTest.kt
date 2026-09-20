package com.dndsync.android.pair

import org.junit.Assert.assertEquals
import org.junit.Test

class PairJoinPolicyTest {
    @Test
    fun samePairIdAlreadyJoinedIsNoOp() {
        assertEquals(
            PairJoinPolicy.Action.AlreadyJoined,
            PairJoinPolicy.action("abc", true, "abc"),
        )
    }

    @Test
    fun samePairIdPendingKeepsIdentity() {
        assertEquals(
            PairJoinPolicy.Action.JoinExistingIdentity,
            PairJoinPolicy.action("abc", false, "abc"),
        )
    }

    @Test
    fun differentPairIdReplaces() {
        assertEquals(
            PairJoinPolicy.Action.ReplaceAndJoin,
            PairJoinPolicy.action("old", true, "new"),
        )
    }
}
