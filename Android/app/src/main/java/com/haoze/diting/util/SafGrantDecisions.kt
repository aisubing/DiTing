package com.haoze.diting.util

/**
 * Decides which persisted SAF grants to release.
 *
 * A-083: the app took a persistable read grant at five call sites and released it
 * at none, so every file the user ever picked stayed readable by the app forever
 * — including files the user later removed from the app. Releasing has to happen
 * in three distinct situations, and getting any of them wrong either leaks the
 * grant (release too little) or breaks a file that is still in use (release too
 * much). The decisions are pure so they can be tested without a ContentResolver.
 */
object SafGrantDecisions {

    /**
     * Grants to release when the file picker returns.
     *
     * @param previousUri the file already selected before this pick, if any.
     * @param pickedUri the file the picker returned; null when the user cancelled.
     * @param accepted whether the picked file passed validation and will be used.
     */
    fun releasesOnPick(
        previousUri: String?,
        pickedUri: String?,
        accepted: Boolean
    ): List<String> {
        // Cancelled picker: nothing new was granted, nothing may be released.
        if (pickedUri == null) return emptyList()

        if (!accepted) {
            // The file was rejected, so its fresh grant must not stay persisted.
            // The previously accepted file is still in use and keeps its grant.
            return listOf(pickedUri)
        }

        // Replacing the selection orphans the old grant. Re-picking the same file
        // must not release the grant that is about to be used again.
        return if (previousUri != null && previousUri != pickedUri) {
            listOf(previousUri)
        } else {
            emptyList()
        }
    }

    /** Grants to release when [uri] is removed from the app's list. */
    fun releasesOnRemove(uri: String?): List<String> {
        val value = uri?.trim().orEmpty()
        return if (value.isEmpty()) emptyList() else listOf(value)
    }
}
