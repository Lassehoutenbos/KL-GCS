#include "sensorhistory.h"
#include <QDir>
#include <QStandardPaths>
#include <QDateTime>
#include <QtSql/QSqlQuery>
#include <QtSql/QSqlError>
#include <QDebug>
#include <QtMath>

SensorHistory::SensorHistory(GCSState *state, QObject *parent)
    : QObject(parent), m_state(state)
{
    m_dbConnName = "picode_history";
}

bool SensorHistory::open()
{
    QString dir = QDir::homePath() + "/.picode";
    QDir().mkpath(dir);
    m_dbPath = dir + "/history.db";

    m_db = QSqlDatabase::addDatabase("QSQLITE", m_dbConnName);
    m_db.setDatabaseName(m_dbPath);
    if (!m_db.open()) {
        qWarning() << "SensorHistory: open failed:" << m_db.lastError().text();
        return false;
    }
    QSqlQuery q(m_db);
    q.exec("PRAGMA journal_mode=WAL");
    q.exec("PRAGMA synchronous=NORMAL");
    return true;
}

void SensorHistory::ensureSchema()
{
    QSqlQuery q(m_db);
    if (!q.exec("CREATE TABLE IF NOT EXISTS samples ("
                " t INTEGER NOT NULL,"
                " k TEXT NOT NULL,"
                " v REAL NOT NULL"
                ")"))
        qWarning() << "SensorHistory: create samples failed:" << q.lastError().text();
    q.exec("CREATE INDEX IF NOT EXISTS idx_samples_kt ON samples(k, t)");
}

void SensorHistory::start()
{
    if (!open()) return;
    ensureSchema();

    m_sampleTimer.setInterval(1000);
    connect(&m_sampleTimer, &QTimer::timeout, this, &SensorHistory::onSampleTick);
    m_sampleTimer.start();

    m_pruneTimer.setInterval(60 * 60 * 1000);
    connect(&m_pruneTimer, &QTimer::timeout, this, &SensorHistory::onPruneTick);
    m_pruneTimer.start();

    QTimer::singleShot(2000, this, &SensorHistory::onPruneTick);
}

void SensorHistory::onSampleTick()
{
    if (!m_state) return;
    QVariantMap snap = m_state->sensorSnapshot();
    qint64 now = QDateTime::currentMSecsSinceEpoch();

    QSqlQuery q(m_db);
    if (!m_db.transaction()) {
        qWarning() << "SensorHistory: txn begin failed";
    }
    q.prepare("INSERT INTO samples (t, k, v) VALUES (?, ?, ?)");
    for (auto it = snap.begin(); it != snap.end(); ++it) {
        bool ok = false;
        double v = it.value().toDouble(&ok);
        if (!ok || qIsNaN(v)) continue;
        q.bindValue(0, now);
        q.bindValue(1, it.key());
        q.bindValue(2, v);
        if (!q.exec()) {
            qWarning() << "SensorHistory: insert failed:" << q.lastError().text();
        }
    }
    m_db.commit();
}

void SensorHistory::onPruneTick()
{
    qint64 cutoff = QDateTime::currentMSecsSinceEpoch() - RETENTION_MS;
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM samples WHERE t < ?");
    q.bindValue(0, cutoff);
    if (!q.exec())
        qWarning() << "SensorHistory: prune failed:" << q.lastError().text();
}

QVariantList SensorHistory::samples(const QString &key, qint64 sinceMs, int maxPoints) const
{
    QVariantList out;
    qint64 since = QDateTime::currentMSecsSinceEpoch() - sinceMs;

    QSqlDatabase db = QSqlDatabase::database(m_dbConnName);
    QSqlQuery c(db);
    c.prepare("SELECT COUNT(*) FROM samples WHERE k = ? AND t >= ?");
    c.bindValue(0, key);
    c.bindValue(1, since);
    int count = 0;
    if (c.exec() && c.next()) count = c.value(0).toInt();
    if (count == 0) return out;

    int stride = qMax(1, count / qMax(1, maxPoints));

    QSqlQuery q(db);
    q.prepare("SELECT t, v FROM samples WHERE k = ? AND t >= ? ORDER BY t ASC");
    q.bindValue(0, key);
    q.bindValue(1, since);
    if (!q.exec()) return out;

    int i = 0;
    while (q.next()) {
        if ((i++ % stride) != 0) continue;
        QVariantMap m;
        m["t"] = q.value(0).toLongLong();
        m["v"] = q.value(1).toDouble();
        out.append(m);
    }
    return out;
}

QStringList SensorHistory::keys() const
{
    QStringList out;
    QSqlDatabase db = QSqlDatabase::database(m_dbConnName);
    QSqlQuery q(db);
    if (!q.exec("SELECT DISTINCT k FROM samples ORDER BY k")) return out;
    while (q.next()) out.append(q.value(0).toString());
    return out;
}
