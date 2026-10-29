package com.dataasset.platform.jobs;

import com.dataasset.platform.service.PowerJobDelegateService;
import org.springframework.stereotype.Component;
import tech.powerjob.worker.core.processor.ProcessResult;
import tech.powerjob.worker.core.processor.TaskContext;
import tech.powerjob.worker.core.processor.sdk.BasicProcessor;

/**
 * PowerJob 统一委托处理器（阶段 C）。
 * 在调度中心创建任务时处理器填本类 Spring Bean 名 delegateJobProcessor，
 * 任务参数填 dam_sched.sched_job 的 job_code（如 QUALITY-FULL / META-SYNC-DEMO / LOG-CLEAN）。
 */
@Component
public class DelegateJobProcessor implements BasicProcessor {

    private final PowerJobDelegateService delegate;

    public DelegateJobProcessor(PowerJobDelegateService delegate) {
        this.delegate = delegate;
    }

    @Override
    public ProcessResult process(TaskContext context) {
        String jobCode = context.getJobParams() == null ? "" : context.getJobParams().trim();
        try {
            String message = delegate.execute(jobCode, context.getInstanceId());
            return new ProcessResult(true, message);
        } catch (Exception e) {
            return new ProcessResult(false, "执行异常：" + e.getMessage());
        }
    }
}
