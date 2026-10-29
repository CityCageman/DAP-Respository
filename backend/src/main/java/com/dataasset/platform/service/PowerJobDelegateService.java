package com.dataasset.platform.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.Map;

/**
 * PowerJob 委托执行服务（阶段 C）：
 * PowerJob 触发 -> DelegateJobProcessor -> 本服务按 job_code 找 dam_sched.sched_job 执行，
 * 执行结果写 dam_sched.sched_job_log 并回写 dam_sched.sched_job 运行状态（双端对账）。
 */
@Service
public class PowerJobDelegateService {

    private static final Logger log = LoggerFactory.getLogger(PowerJobDelegateService.class);

    private final JdbcTemplate jdbc;
    private final QualityService qualityService;
    private final DamMetadataSyncService damMetadataSyncService;

    public PowerJobDelegateService(JdbcTemplate jdbc, QualityService qualityService,
                                   DamMetadataSyncService damMetadataSyncService) {
        this.jdbc = jdbc;
        this.qualityService = qualityService;
        this.damMetadataSyncService = damMetadataSyncService;
    }

    /** 执行入口，返回给 PowerJob 的执行结果消息 */
    public String execute(String jobCode, Long instanceId) {
        Map<String, Object> job;
        try {
            job = jdbc.queryForMap(
                    "select * from dam_sched.sched_job where job_code = ? and deleted_at is null", jobCode);
        } catch (Exception e) {
            return "dam_sched.sched_job 无此任务：" + jobCode;
        }
        if (!Boolean.TRUE.equals(job.get("enabled"))) {
            return "任务 " + jobCode + " 已停用，跳过执行";
        }
        long jobId = ((Number) job.get("id")).longValue();
        String jobType = String.valueOf(job.get("job_type"));
        LocalDateTime start = LocalDateTime.now();
        long t0 = System.currentTimeMillis();
        String status = "SUCCESS";
        String message;
        try {
            message = doJob(jobType, jobCode);
        } catch (Exception e) {
            log.error("PowerJob 委托任务 {} 执行失败", jobCode, e);
            status = "FAIL";
            message = e.getMessage() == null ? e.toString() : e.getMessage();
        }
        long duration = System.currentTimeMillis() - t0;
        try {
            jdbc.update("""
                    insert into dam_sched.sched_job_log(job_id, started_at, finished_at, duration_ms,
                                                  exec_status, message, powerjob_instance_id, created_by)
                    values (?,?,?,?,?,?,?, 'powerjob')
                    """, jobId, start, LocalDateTime.now(), duration, status, message, instanceId);
            jdbc.update("""
                    update dam_sched.sched_job set last_run_at = ?, last_status = ?, last_message = ?,
                           run_count = run_count + 1 where id = ?
                    """, start, status, message, jobId);
        } catch (Exception e) {
            log.warn("写 dam 调度日志失败：{}", e.getMessage());
        }
        return status + "：" + message;
    }

    private String doJob(String jobType, String jobCode) {
        return switch (jobType) {
            case "QUALITY_CHECK", "QUALITY_RUN_ALL" -> {
                qualityService.runAll();
                yield "全部质量规则执行完成";
            }
            case "METADATA_SYNC" -> damMetadataSyncService.syncAll();
            case "LOG_CLEAN", "API_LOG_CLEAN" -> {
                int n1 = jdbc.update(
                        "delete from api_call_log where called_at < now() - interval '90 days'");
                int n2 = jdbc.update(
                        "delete from dam_service.api_call_log where called_at < now() - interval '90 days'");
                yield "清理 90 天前网关调用日志 " + n1 + " + " + n2 + " 条";
            }
            default -> "未知任务类型 " + jobType + "，已跳过";
        };
    }
}
