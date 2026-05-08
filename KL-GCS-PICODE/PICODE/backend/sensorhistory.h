#pragma once
#include <QObject>
#include <QVariantList>
#include <QString>
#include <QTimer>
#include <QtSql/QSqlDatabase>
#include "gcsstate.h"

class SensorHistory : public QObject {
    Q_OBJECT
public:
    explicit SensorHistory(GCSState *state, QObject *parent = nullptr);
    void start();

    // Returns list of {t (ms epoch), v (double)} for the given key, since `sinceMs`
    // ago up to now. `maxPoints` downsamples by stride.
    Q_INVOKABLE QVariantList samples(const QString &key, qint64 sinceMs,
                                     int maxPoints = 600) const;

    // Returns list of distinct sensor keys recorded.
    Q_INVOKABLE QStringList keys() const;

private slots:
    void onSampleTick();
    void onPruneTick();

private:
    bool open();
    void ensureSchema();

    GCSState     *m_state;
    QSqlDatabase  m_db;
    QString       m_dbConnName;
    QString       m_dbPath;
    QTimer        m_sampleTimer;   // 1 Hz writes
    QTimer        m_pruneTimer;    // hourly prune
    static constexpr qint64 RETENTION_MS = 7LL * 24 * 60 * 60 * 1000;
};
