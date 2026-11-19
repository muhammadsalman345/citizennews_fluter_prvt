# WorkManager 2.7 uses Room 2.2 and reflects its generated database class.
# AGP 9/R8 can otherwise remove the constructor while retaining the class name,
# causing a crash in InitializationProvider before Flutter starts.
-keep class * extends androidx.room.RoomDatabase {
    *;
}
