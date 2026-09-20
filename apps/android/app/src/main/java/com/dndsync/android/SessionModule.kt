package com.dndsync.android

import android.os.Handler
import android.os.Looper
import com.dndsync.android.cloud.ForwarderClient
import com.dndsync.android.dnd.DndApply
import com.dndsync.android.dnd.ZenDndApply
import com.dndsync.android.lan.LanSyncService
import com.dndsync.android.pair.FcmTokenStore
import com.dndsync.android.pair.PairForwarder
import com.dndsync.android.pair.PairSession
import com.dndsync.android.pair.PairStore
import com.dndsync.android.pair.PairStoring
import com.dndsync.android.sync.SyncCloud
import com.dndsync.android.sync.SyncLan
import com.dndsync.android.sync.SyncSession
import com.dndsync.android.ui.onboarding.OnboardingPrefsStore
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class SessionBindModule {
    @Binds
    abstract fun pairStore(impl: PairStore): PairStoring

    @Binds
    abstract fun pairForwarder(impl: ForwarderClient): PairForwarder

    @Binds
    abstract fun syncLan(impl: LanSyncService): SyncLan

    @Binds
    abstract fun syncCloud(impl: ForwarderClient): SyncCloud

    @Binds
    abstract fun dndApply(impl: ZenDndApply): DndApply
}

@Module
@InstallIn(SingletonComponent::class)
object SessionModule {
    @Provides
    @Singleton
    fun pairSession(
        forwarder: PairForwarder,
        store: PairStoring,
        tokens: FcmTokenStore,
    ): PairSession {
        val main = Handler(Looper.getMainLooper())
        return PairSession(
            forwarder,
            store,
            token = { tokens.token },
            postToMain = { action -> main.post(action) },
        )
    }

    @Provides
    @Singleton
    fun syncSession(
        lan: SyncLan,
        cloud: SyncCloud,
        pair: PairSession,
        apply: DndApply,
        onboarding: OnboardingPrefsStore,
    ): SyncSession {
        val sync = SyncSession(lan, cloud, pair)
        pair.onNotifyPeerUnpair = { sync.sendUnpair(it) }
        pair.onPairIdChange = { id ->
            sync.setPairId(id)
            sync.startLANIfJoined()
        }
        pair.onJoined = { sync.startLANIfJoined() }
        pair.onCleared = {
            sync.stopLAN()
            onboarding.clearOnboardingComplete()
        }
        apply.onLocalChange = { on -> sync.onLocalFocusChange(on) }
        apply.onObserverEvent = { sync.noteObserverEvent() }
        sync.onApplyRemote = { apply.apply(it) }
        sync.setPairId(pair.pairId)
        sync.startLANIfJoined()
        return sync
    }
}
