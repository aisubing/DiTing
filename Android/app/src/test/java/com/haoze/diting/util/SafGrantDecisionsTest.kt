package com.haoze.diting.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A-083: the app called `takePersistableUriPermission` at five sites and
 * `releasePersistableUriPermission` at none. A persistable grant survives
 * reboots, so every file the user ever picked stayed readable by the app — even
 * after the user deleted the wallpaper or replaced the subscription file.
 *
 * The three release situations are easy to get subtly wrong in the opposite
 * direction too (releasing a grant for a file that is still in use), so the
 * decisions are pinned down here.
 */
class SafGrantDecisionsTest {

    private val old = "content://com.android.providers.downloads.documents/document/1"
    private val new = "content://com.android.providers.downloads.documents/document/2"

    @Test
    fun rejectedPickReleasesItsOwnGrant() {
        // The .txt check fails after the grant was already taken; the file is
        // never used, so its grant must not stay persisted.
        assertEquals(listOf(new), SafGrantDecisions.releasesOnPick(old, new, accepted = false))
    }

    @Test
    fun rejectedPickKeepsThePreviousFilesGrant() {
        // The previously accepted file is still selected and still in use.
        val released = SafGrantDecisions.releasesOnPick(old, new, accepted = false)
        assertEquals(false, released.contains(old))
    }

    @Test
    fun replacedPickReleasesThePreviousGrant() {
        // Picking a second file orphans the first one's grant.
        assertEquals(listOf(old), SafGrantDecisions.releasesOnPick(old, new, accepted = true))
    }

    @Test
    fun firstPickReleasesNothing() {
        assertTrue(SafGrantDecisions.releasesOnPick(null, new, accepted = true).isEmpty())
    }

    @Test
    fun rePickingTheSameFileKeepsItsGrant() {
        // Releasing here would revoke the grant that is about to be used.
        assertTrue(SafGrantDecisions.releasesOnPick(new, new, accepted = true).isEmpty())
    }

    @Test
    fun cancelledPickerReleasesNothing() {
        // No new grant was created, and the existing selection must keep its own.
        assertTrue(SafGrantDecisions.releasesOnPick(old, null, accepted = true).isEmpty())
        assertTrue(SafGrantDecisions.releasesOnPick(old, null, accepted = false).isEmpty())
        assertTrue(SafGrantDecisions.releasesOnPick(null, null, accepted = true).isEmpty())
    }

    @Test
    fun removingAWallpaperReleasesItsGrant() {
        assertEquals(listOf(new), SafGrantDecisions.releasesOnRemove(new))
    }

    @Test
    fun removingABlankUriReleasesNothing() {
        assertTrue(SafGrantDecisions.releasesOnRemove(null).isEmpty())
        assertTrue(SafGrantDecisions.releasesOnRemove("").isEmpty())
        assertTrue(SafGrantDecisions.releasesOnRemove("   ").isEmpty())
    }

    @Test
    fun everyDecisionReturnsAtMostOneUri() {
        // Releasing more than the URI being replaced/removed would revoke grants
        // that are still needed.
        val cases = listOf(
            SafGrantDecisions.releasesOnPick(old, new, accepted = true),
            SafGrantDecisions.releasesOnPick(old, new, accepted = false),
            SafGrantDecisions.releasesOnPick(new, new, accepted = true),
            SafGrantDecisions.releasesOnPick(null, new, accepted = true)
        )
        cases.forEach { assertTrue(it.size <= 1) }
    }
}
